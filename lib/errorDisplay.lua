local M = {} -- public interface

function M.displayError(status, msg)
    ngx.status = status
    ngx.header.content_type = 'text/plain'
    ngx.say(msg)
end

return M
