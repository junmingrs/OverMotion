local M = {}

local entries = {}
local path = vim.fn.stdpath('data') .. '/overmotion/leaderboard.json'

local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local f = io.open(path, 'w')
  if f then
    f:write(vim.json.encode(entries))
    f:close()
  end
end

function M.load()
  local f = io.open(path, 'r')
  if f then
    local content = f:read('*a')
    f:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == 'table' then
      entries = data
    end
  end
  table.sort(entries, function(a, b)
    return a.keystrokes < b.keystrokes
  end)
end

function M.add(entry)
  table.insert(entries, entry)
  table.sort(entries, function(a, b)
    return a.keystrokes < b.keystrokes
  end)
  save()
end

function M.count()
  return #entries
end

function M.lines()
  local lines = { 'LEADERBOARD', '', 'Attempts: ' .. #entries, '' }
  for i, e in ipairs(entries) do
    if i > 20 then
      break
    end
    local sentence = e.sentence or ''
    if #sentence > 18 then
      sentence = sentence:sub(1, 15) .. '...'
    end
    table.insert(lines, string.format('%d. %d keys', i, e.keystrokes))
    table.insert(lines, '   ' .. sentence)
  end
  return lines
end

function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines())
  vim.bo[buf].modifiable = false
end

return M
