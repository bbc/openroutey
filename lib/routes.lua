-- Finds a route from the route config.
-- TODO: Re-read from file periodically.
-- TODO: Store and read routes in Redis, so that they can be shared between Nginx boxes.
-- (This is required so that the service can continue if routes cannot be fetched.)

local M = {} -- public interface
local routesDir

function M.findRoute()
    loadRoutes()
    return findRouteInLoadedRoutes()
end

-- (Re)loads the primary routes file. Returns TRUE iff successful.
-- This only needs to be called explicitly when there is need to reconsider the routes.
function M.reloadRoutesFile()
    local sharedDict = ngx.shared.openroutey
    local routesFile
    routesDir, routesFile = string.match(config.routesFile , "^(.+)/(.+)$")
    local newRoutes = processRoutesFile(routesFile)
    if newRoutes then
        M.routes = newRoutes
        local routesEncoded, encodingErrors = jsonSafe.encode(M.routes)
        if encodingErrors then
            ngx.log(ngx.ERR, "Failed to encode routes:" .. encodingErrors)
        else
            sharedDict:set('routes', routesEncoded)
        end
        ngx.log(ngx.ERR, "OpenRoutey routes loaded")
        return true
    end

    ngx.log(ngx.ERR, "OpenRoutey routes FAILED to load")
    return false
end

function loadRoutes()
    if M.resetRoutes then
        M.resetRoutes = false
        M.reloadRoutesFile()
        return
    end

    if M.routes then return end
    loadRoutesFromSharedDictionary()
    if M.routes then return end
    M.reloadRoutesFile()
end

function loadRoutesFromSharedDictionary()
    local sharedDict = ngx.shared.openroutey
    local routesJsonInSharedDict = sharedDict:get('routes')
    if not routesJsonInSharedDict then return end
    local decoded, decodeErrors = jsonSafe.decode(routesJsonInSharedDict)
    if decodeErrors then
        ngx.log(ngx.ERR, "Invaid routes JSON in shared dictionary")
    else
        M.routes = decoded
    end
end

function findRouteInLoadedRoutes()
    for count, routeDetails in pairs(M.routes) do
        -- ngx.log(ngx.ERR, "Considering:" .. ngx.var.uri .. ":" .. json.encode(routeDetails))
        if (routeDetails.pathMatch) then
            local attempt = string.match(ngx.var.uri, routeDetails.pathMatch);
            if (attempt) then return routeDetails end
        end
    end
end

function readRoutesFile(filename)
    local fileNameFullPath = routesDir .. '/' .. filename
    -- ngx.log(ngx.ERR, "NOW TRYING " .. fileNameFullPath)
    local file = io.open(fileNameFullPath, "r" )

    if file then
        local contents = file:read( "*a" )
        io.close( file )

        local decoded, decodeErrors = jsonSafe.decode(contents)
        if (decodeErrors) then
            ngx.log(ngx.ERR, "Failed to read " .. fileNameFullPath .. ":" .. decodeErrors)
            return
        end

        return decoded
    end

    ngx.log(ngx.ERR, "Unable to find " .. fileNameFullPath)
    return nil
end

-- Processes the file and returns an array of routes in it
function processRoutesFile(filename, origins)
    local routesFileContents = readRoutesFile(filename)
    if (routesFileContents == nil) then
        ngx.log(ngx.ERR, "Failed to load " .. filename)
        return nil
    end

    local origins = readOrigins(routesFileContents, origins)
    return readRoutes(routesFileContents.routes, origins)
end

function processRoutesUri(url, origins)
    local response, cacheStatus = originCaller.callOriginUriIncludingCheckCache(url)
    if (response.status ~= 200) then
        ngx.log(ngx.ERR, "Failed to load '" .. url .. "', response code was " .. response.status)
        return {}
    end

    local routesFileContents, decodeErrors = jsonSafe.decode(response.body)
    if (decodeErrors) then
        ngx.log(ngx.ERR, "Failed to decode " .. url .. ":" .. decodeErrors)
        return {}
    end

    local origins = readOrigins(routesFileContents, origins)
    return readRoutes(routesFileContents.routes, origins)
end

-- Reads and handles the list of routes in a routes JSON file
function readRoutes(routes, origins)
    local theseRoutes = {}
    for count, routeDetails in pairs(routes) do
        local moreRoutes = processRoute(routeDetails, origins)
        if (moreRoutes) then
            theseRoutes = appendToArray(theseRoutes, moreRoutes)
        end
    end

    return theseRoutes
end

-- Takes a single route in the JSON. Returns an array of routes that have been
-- discovered from it. There may be more than one if the route references
-- a routes file that contains many other routes.
function processRoute(routeDetails, origins)
    if (routeDetails.routesFile) then
        return processRoutesFile(routeDetails.routesFile, origins)
    end

    if (routeDetails.routesUri) then
        return processRoutesUri(routeDetails.routesUri, origins)
    end

    if routeDetails.originId then
        local merged = mergeRouteDetailsWithOrigin(routeDetails, origins)
        if merged then return {merged} end
        return {}
    end

    return {routeDetails}
end

function appendToArray(a1, a2)
    for k,v in pairs(a2) do table.insert(a1, v) end
    return a1
end

-- When a route references an origin, this takes all origin details and adds it to the route.
function mergeRouteDetailsWithOrigin(routeDetails, origins)
    if not origins[routeDetails.originId] then
        ngx.log(ngx.ERR, "Origin '" .. routeDetails.id ..
            "' references unknown origin ID '" .. routeDetails.originId .. "'")
        return
    end

    for k,v in pairs(origins[routeDetails.originId]) do
        if k  ~= "id" then routeDetails[k] = v end
    end

    routeDetails.originUri = (routeDetails.originProtocolAndDomain or '') ..
        (routeDetails.originPath or '${uri}') .. -- /uri is the default
        (routeDetails.originPathPostfix or '')

    return routeDetails
end

-- Handles the 'origins' array in the JSON routes file.
function readOrigins(routesFileContents, origins)
    if not origins then origins = {} end
    if not routesFileContents.origins then return origins end
    for count, origin in pairs(routesFileContents.origins) do
        if not origin.id then
            ngx.log(ngx.ERR, "An origin is missing 'id' value")
        elseif not origin.originProtocolAndDomain then
            ngx.log(ngx.ERR, "Origin '" .. id .. "' is missing 'originProtocolAndDomain'")
        else
            origins[origin.id] = origin
        end
    end

    return origins
end

return M
