local M = {}

local count = 0
local start_time = nil
local edit_win = nil
local ns_id = vim.api.nvim_create_namespace('overmotion_tracker')

local function on_key(key, typed)
  if not edit_win or not vim.api.nvim_win_is_valid(edit_win) then
    return
  end
  if vim.api.nvim_get_current_win() ~= edit_win then
    return
  end
  count = count + 1
  if not start_time then
    start_time = vim.uv.now()
  end
end

function M.attach(win)
  edit_win = win
  count = 0
  start_time = nil
  vim.on_key(on_key, ns_id)
end

function M.detach()
  edit_win = nil
  vim.on_key(nil, ns_id)
end

function M.reset()
  count = 0
  start_time = nil
end

function M.count()
  return count
end

function M.elapsed_ms()
  if not start_time then
    return 0
  end
  return vim.uv.now() - start_time
end

return M
