local M = {} -- public interface

local JSON = require "cjson"
local redisCache = require "redisCache"
local stringHelper = require "stringHelper"

-- For a URL, either gets it from the catch, or fetches it.
-- Returns the response, and also the cache status (STALE/EXPIRED/MISS)
function M.callOriginUriIncludingCheckCache(originUri)
    local cacheStatus,etag = redisCache.urlStatus(originUri)
    -- ngx.log(ngx.ERR, 'Cache status for ', originUri, ' is ', cacheStatus)
    if cacheStatus == redisCache.STALE then
        response = callOriginUri(originUri,etag)
        if (response.status >= 500 or response.status == 202) then
            response = redisCache.getCachedResponse(originUri)
            cacheStatus = 'STALE'
        else
            cacheStatus = 'EXPIRED'
        end
    elseif cacheStatus == redisCache.HIT then
        response = redisCache.getCachedResponse(originUri)
        cacheStatus = 'HIT'
    else -- MISS
        response = callOriginUri(originUri)
        cacheStatus = 'MISS'
    end

    return response, cacheStatus
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

return M
