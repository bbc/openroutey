local M = {} -- public interface
local redisLib = require "resty.redis"

-- Some constants. We use strings as values to make it easier to debug.
M.HIT = 'HIT'
M.MISS = 'MISS'
M.STALE = 'STALE'

-- Given a URL and response from origin, stores it in Redis, if permitted
function M.storeResponse(url, response)
    local cacheSeconds = getCacheSeconds(response)
    if cacheSeconds == nil then return end -- Don't cache if we're not supposed to

    local responseEncoded, responseErrors = jsonSafe.encode(response)
    if (reponseErrors) then
        ngx.log(ngx.ERR, "Failed to encode response:" .. reponseErrors)
        return
    end

    local properties = {
        url = url,
        timestamp = ngx.now(),
        cacheSeconds = cacheSeconds,
        response = responseEncoded
    }

    if (response.header["ETag"]) then properties.etag = response.header["ETag"] end

    local redis = getRedis()
    if not redis then return end
    ok, err = redis:hmset("origin:" .. url, properties)
    closeRedis(redis)

    if not ok then ngx.log(ngx.ERR, "Failed to set origin in Redis:" .. err) end
end

-- Returns:
--    HIT if in cache and fresh
--    MISS if not in cache
--    STALE if in cache and not fresh
function M.urlStatus(url)
    local redis = getRedis()
    if (not redis) then return M.MISS end
    local res,err = redis:hmget("origin:" .. url, "timestamp", "cacheSeconds", "etag")
    if (err or not res) then
        ngx.log(ngx.ERR, 'REDIS ERROR:', err)
        return M.MISS
    end
    closeRedis(redis)
    local timestamp = tonumber(res[1])
    local cacheSeconds = tonumber(res[2])
    local etag = res[3]
    if timestamp == nil or cacheSeconds == nil then return M.MISS end

    local isFresh = (timestamp + cacheSeconds > ngx.now())
    if isFresh then return M.HIT else return M.STALE,etag end
end

-- Given a URL, returns the cache of the respone we received from origin
function M.getCachedResponse(url)
    local redis = getRedis()
    local responseJson,err = redis:hget("origin:" .. url, "response")
    local responseDecoded, responseErrors = jsonSafe.decode(responseJson)
    if responseErrors then ngx.log(ngx.ERR, "Failed to set decode:" .. err) end
    return responseDecoded
end

-- Given a response, returns the number of seconds it can be cached for, or nil if not
function getCacheSeconds(response)
    local cacheControl = response.header["Cache-Control"]
    if not cacheControl then return nil end
    if ngx.re.match(cacheControl, "no-cache") then return nil end
    if ngx.re.match(cacheControl, "private") then return nil end
    local maxAgeMatch = ngx.re.match(cacheControl, "max-age=(?<age>[0-9]+)")
    if (maxAgeMatch) then return maxAgeMatch.age end
    return nil
end

function getRedis()
    local redis = redisLib:new()

    -- 1 second timeout. Intentionally small so as not to offer very slow responses
    -- if Redis is struggling.
    redis:set_timeout(1000)

    local ok, err = redis:connect(config.redisHost, config.redisPort)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect to Redis: ", err)
        redis:set_keepalive(10000, 100)
        return
    end
    return redis
end

function closeRedis(redis)
    redis:set_keepalive(10000, 100)
end

return M
