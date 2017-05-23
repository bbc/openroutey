local M = {} -- public interface
local redisLib = require "resty.redis"
local JSON = require "cjson"
local config = require "config"

-- Some constants. We use strings as values to make it easier to debug.
M.HIT = 'HIT'
M.MISS = 'MISS'
M.STALE = 'STALE'

-- Given a URL and response from origin, stores it in Redis
function M.storeResponse(url, response)
    local cacheSeconds = getCacheSeconds(response)
    -- ngx.log(ngx.ERR, "cache seconds for: ", url, " is ", cacheSeconds, " and etag is ", response.header["Etag"])
    -- ngx.log(ngx.ERR, "HEADER:", JSON.encode(response.header))
    if cacheSeconds == nil then return end

    local properties = {
        url= url, timestamp= ngx.now(),
        cacheSeconds=cacheSeconds, response= JSON.encode(response)
    }

    if (response.header["ETag"]) then properties.etag = response.header["ETag"] end
    if (response.header["Etag"]) then properties.etag = response.header["Etag"] end

    local redis = getRedis()
    if not redis then return end
    ok, err = redis:hmset("origin:" .. url, properties)
    closeRedis(redis)

    if not ok then
        ngx.log(ngx.ERR, "Failed to set origin in Redis:" .. err)
        return value
    end
    return
end

-- Returns:
--    HIT if in cache and fresh
--    MISS if not in cache
--    STALE if in cache and not fresh
function M.urlStatus(url)
    local redis = getRedis()
    if (not redis) then return M.MISS end
    local res,err = redis:hmget("origin:" .. url, "timestamp", "cacheSeconds", "etag")
    -- ngx.log('REDIS ERROR:', ngx.ERR, "urlStatus:", url, " timestamp ", res[1], "cachSec:", res[2])
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
    -- ngx.log(ngx.ERR, "urlStatus:", url, " timestamp ", res[1], "cachSec:", res[2], "DIFF", (timestamp + cacheSeconds) - ngx.now())
    if isFresh then return M.HIT else return M.STALE,etag end
end

function M.getCachedResponse(url)
    local redis = getRedis()
    local responseJson,err = redis:hget("origin:" .. url, "response")
    return JSON.decode(responseJson)
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
    redis:set_timeout(1000) -- 1 sec
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
