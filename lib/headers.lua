local M = {} -- public interface

local headersNotToPassFromOrigin = { Server=true, ["Keep-Alive"]=true, Connection=true, ["Content-Encoding"]=true, ["X-Powered-By"]=true, ["Content-Length"]=true }

-- Copy headers from origin response into this response
-- Ensure that X-Route-SOMETHING is converted, replacing what was already there
function M.copyHeadersFromOriginResponse(res)
    for name, value in pairs(res.header) do
        if (not headersNotToPassFromOrigin[name]) then
            local overrideMatch = ngx.re.match(name, "^X-Route-(?<realName>.+)$")

            -- If there's an X-Route-Foo, set Foo, replacing what's there
            if (overrideMatch) then
                ngx.header[overrideMatch.realName] = value

            -- Else, set header unless it's already set, in which case, discard
            elseif not ngx.header[name] then
                ngx.header[name] = value
            end
        end
    end
end

return M
