local M = {} -- public interface

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

function M.getEncodedPath()
    -- local path_without_start = string.match(ngx.var.uri, '^/(.+)')
    -- We encode twice, because Nginx will decode once when we make the request:
    return ngx.escape_uri(ngx.escape_uri(ngx.var.uri))
end

return M
