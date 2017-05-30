local M = {} -- public interface

-- Given URI, returns domain, path, and args as separate strings
function M.splitDomainAndPathAndArgs(uri)
    local m = ngx.re.match(uri, "^(?<domain>http(s?)://([^/]+))(?<path>.*)$")
    if not m then return nil, nil, nil end

    local pathWithoutArgs, args = splitPathAndArgs(m.path)
    return m.domain, pathWithoutArgs, args
end

function splitPathAndArgs(pathAndArgs)
    local m = ngx.re.match(pathAndArgs, "^(?<path>[^?]*)%?(?<args>.*)$")
    if not m then return pathAndArgs, "" end
    return m.path, m.args
end

-- Handles the presence of ${thing} within the config URI
function M.completeOriginUri(origin)
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
            value = getEncodedPath()
        elseif (field == "uri") then
            value = ngx.var.uri
        end

        origin = ngx.re.sub(origin, "\\${"..field.."}", value)
     end

     return origin
end

function getEncodedPath()
    -- local path_without_start = string.match(ngx.var.uri, '^/(.+)')
    -- We encode twice, because Nginx will decode once when we make the request:
    return ngx.escape_uri(ngx.escape_uri(ngx.var.uri))
end

return M
