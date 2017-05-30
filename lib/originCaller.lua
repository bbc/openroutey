local M = {} -- public interface
local redisCache = require "redisCache"
local stringHelper = require "stringHelper"

-- Call the origin, and return the response
function M.callOrigin(routeDetails)
    local originUri = stringHelper.completeOriginUri(routeDetails.originUri)
    local response, cacheStatus = M.callOriginUriIncludingCheckCache(originUri)
    ngx.header.X_Router_Cache = cacheStatus
    return response
end

-- For a URL, either gets it from the catch, or fetches it.
-- Returns the response, and also the cache status (STALE/EXPIRED/MISS)
function M.callOriginUriIncludingCheckCache(originUri)

    -- Intentionally only retrieve the status from Redis, not the body until needed.
    local cacheStatus, etag = redisCache.urlStatus(originUri)
    if cacheStatus == redisCache.HIT then
        local cachedResponse = redisCache.getCachedResponse(originUri)
        if cachedResponse then return cachedResponse, 'HIT' end
    elseif cacheStatus == redisCache.STALE then
        local response = callOriginUri(originUri, etag)
        local responseSuccessful = (response.status < 500 and response.status ~= 202)
        if responseSuccessful then return response, 'EXPIRED' end
        local staleResponse = redisCache.getCachedResponse(originUri)
        if staleResponse then return staleResponse, 'STALE' end
    end

    return callOriginUri(originUri), 'MISS'
end

function callOriginUri(url, etag)
    local domain, path, argsString = stringHelper.splitDomainAndPathAndArgs(url)
    local options = { domain = domain, allargs = argsString }
    if (etag ~= ngx.null) then options.etag = etag end
    local res = ngx.location.capture("/call" .. path, { args = options })
    logResponse(domain, path, res)
    if res.status < 500 then redisCache.storeResponse(url, res) end
    return res
end

-- Logging of every response
function logResponse(domain, path, res)
    ngx.log(ngx.ERR, "originUri=" .. domain .. ngx.unescape_uri(path) .. ", originResponse=" .. res.status)
end

return M
