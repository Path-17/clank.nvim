local M = {}

function M.say_hello()
    vim.notify("Hello from plugin!", vim.log.levels.INFO)
end

return M
