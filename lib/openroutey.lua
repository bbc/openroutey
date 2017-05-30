local M = {} -- public interface

if not config then config = require "config" end
if not json then json = require "cjson" end
if not jsonSafe then jsonSafe = require "cjson.safe" end
if not routes then routes = require "routes" end
if not originCaller then originCaller = require "originCaller" end

local envelope = require "envelope"
local stringHelper = require "stringHelper"
local redisCache = require "redisCache"
local headers = require "headers"
local errorDisplay = require "errorDisplay"

-- Called once whenever OpenResty is started/restarted/reloaded
function M.init(updatedConfig)
    config.set(updatedConfig)
    routes.resetRoutes = true
    ngx.log(ngx.ERR, "OpenRoutey initialised")
end

-- Called whenever there is a route to handle
function M.go()
    local route = routes.findRoute()
    if (route) then
        processFoundRouting(route)
    else
        errorDisplay.displayError(404, 'Route not defined in JSON')
    end
end

-- Once a route has been found, handle it
function processFoundRouting(routeDetails)
    if routeDetails.originUri then
        callOrigin(routeDetails)
    elseif routeDetails.status and (routeDetails.status == 301 or routeDetails.status == 302) then
        if (not routeDetails.location) then
            errorDisplay.displayError(500, 'Incomplete redirect')
        else
            ngx.redirect(routeDetails.location, routeDetails.status)
        end
    elseif routeDetails.status then
        ngx.status = routeDetails.status
        if (routeDetails.body) then
            ngx.say(routeDetails.body)
        end
        ngx.exit(ngx.status)
    else
        errorDisplay.displayError(500, 'Invalid routing')
    end
end

-- Handles the presence of ${thing} within the config URI
function completeOriginUri(origin)
    local iterator, err = ngx.re.gmatch(origin, "\\${([^}]+)}")
    if not iterator then
        ngx.log(ngx.ERR, "error: ", err)
        return
    end

    while true do
        local m, err = iterator()
        if err then
            ngx.log(ngx.ERR, "error: ", err)
            return
        end

        if not m then break end -- no match found (any more)

        local field = m[1]
        local value = ""
        if (field == "envDot") then
            value = "" -- TODO set as test. and int. when on those envs
        elseif (field == "env") then
            value = "live" -- TODO set as test. and int. when on those envs
        elseif (field == "isUkBoolean") then
            value = "true" -- TODO set as "true" or "false" based on Varnish header
        elseif (field == "uriEncoded") then
            value = stringHelper.getEncodedPath()
        elseif (field == "uri") then
            value = ngx.var.uri
        end

        origin = ngx.re.sub(origin, "\\${"..field.."}", value)
     end

     return origin
end

-- Logging of every response
function logResponse(domain, path, res)
    ngx.log(ngx.ERR, "originUri=" .. domain .. ngx.unescape_uri(path) .. ", originResponse=" .. res.status)
end

-- Call the origin, and then return it to the user
function callOrigin(routeDetails)
    local originUri = completeOriginUri(routeDetails.originUri)
    local response, cacheStatus = originCaller.callOriginUriIncludingCheckCache(originUri)
    ngx.header.X_Router_Cache = cacheStatus
    sendResponse(routeDetails, response)
end

-- Send the response to the user
function sendResponse(routeDetails, res)
    headers.copyHeadersFromOriginResponse(res)
    if res.status == 200 then
        ngx.status = 200
        if (routeDetails.transform and routeDetails.transform == "envelope") then
            envelope.transform(res)
        end

        ngx.header.content_type = res.header['Content-Type']
        ngx.say(res.body)
    else
        ngx.status = res.status
        ngx.header.content_type = 'text/plain'
        ngx.say(res.status)
        ngx.exit(res.status)
    end
end

return M
