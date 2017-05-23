local M = {}
function M.set(updatedConfig)
    for key,value in pairs(updatedConfig) do
        M[key] = value
    end
end

return M
