local M = {}

function M.normalize(s)
  s = s:gsub('%s+', ' ')
  return vim.trim(s)
end

function M.buffer_matches(buf, target)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = M.normalize(table.concat(lines, ' '))
  return #content > 0 and content == M.normalize(target)
end

return M
