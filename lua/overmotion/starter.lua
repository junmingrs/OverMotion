local M = {}

function M.show()
  pcall(function()
    require('mini.starter').open()
  end)
end

return M
