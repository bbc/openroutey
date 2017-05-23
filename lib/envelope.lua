local M = {} -- public interface

function M.transform(res)
    if not string.match(res.header['Content-Type'], "application/json") then return end
    local decoded, decodeErors = jsonSafe.decode(res.body)
    if (decodeErrors or decoded == nil) then
        res.header['Content-Type'] = 'text/plain'
        res.body = 'Invalid Envelope JSON'
        ngx.status = 500
        return
    end
    res.header['Content-Type'] = 'text/html'
    local html = "<!DOCTYPE html>\n<html>\n<head>\n"

    if decoded.head then
        if (type(decoded.head == 'table')) then
            for id, entry in pairs(decoded.head) do
                html = html .. entry
            end
        end
    end
    html = html .. "\n</head>\n<body>\n"
    if decoded.bodyInline then
        if (type(decoded.bodyInline == 'string')) then
            html = html .. decoded.bodyInline
        end
    end
    if decoded.bodyLast then
        if (type(decoded.bodyLast == 'table')) then
            for id, entry in pairs(decoded.bodyLast) do
                html = html .. entry
            end
        end
    end

    html = html .. "\n<!-- Generated by Morph Router at " .. ngx.localtime() .. " -->\n</body>\n<html>"
    res.body = html
end

return M