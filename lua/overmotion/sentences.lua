local M = {}

local sentences = {}
local loaded = false
local last_index = -1

local function load()
  if loaded then
    return
  end
  local path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h') .. '/data/sentences.txt'
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok and lines then
    for _, line in ipairs(lines) do
      local s = vim.trim(line)
      if #s > 0 then
        table.insert(sentences, s)
      end
    end
  end
  if #sentences == 0 then
    sentences = { 'the quick brown fox jumps over the lazy dog.' }
  end
  loaded = true
end

function M.random()
  load()
  local idx
  repeat
    idx = math.random(#sentences)
  until idx ~= last_index or #sentences == 1
  last_index = idx
  return sentences[idx]
end

return M
