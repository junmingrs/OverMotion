local M = {}

function M.encode(msg)
  return vim.json.encode(msg)
end

function M.decode(line)
  local ok, msg = pcall(vim.json.decode, line)
  if ok and type(msg) == 'table' and msg.type then
    return msg
  end
  return nil
end

return M
