local M = {}

local uv = vim.uv

local WIDTH = 60
local HEIGHT = 14
local MESSAGE_ROW = 7
local MESSAGE = 'Waiting for host to start'
local TICK_MS = 400

local buf = nil
local win = nil
local host = nil
local timer = nil
local dots = 1
local on_quit = nil

local function valid()
  return buf
    and vim.api.nvim_buf_is_valid(buf)
    and win
    and vim.api.nvim_win_is_valid(win)
end

local function center(text)
  local pad = math.max(0, math.floor((WIDTH - #text) / 2))
  return string.rep(' ', pad) .. text
end

local function render()
  if not valid() then
    M.close()
    return
  end
  local lines = {}
  for i = 1, HEIGHT do
    lines[i] = ''
  end
  lines[1] = center('JOINED - IP: ' .. (host or 'unknown'))
  lines[MESSAGE_ROW] = center(MESSAGE .. string.rep('.', dots))
  lines[HEIGHT] = '  [q] Disconnect'

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function stop_timer()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

function M.is_open()
  return valid()
end

function M.open(server_host, quit_callback)
  host = server_host or host
  on_quit = quit_callback or on_quit

  if valid() then
    render()
    return
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false

  local ok, w = pcall(vim.api.nvim_open_win, buf, true, {
    relative = 'editor',
    row = math.max(0, math.floor((vim.o.lines - HEIGHT) / 2)),
    col = math.max(0, math.floor((vim.o.columns - WIDTH) / 2)),
    width = WIDTH,
    height = HEIGHT,
    style = 'minimal',
    border = 'single',
  })
  if not ok then
    buf = nil
    return
  end
  win = w

  vim.keymap.set('n', 'q', function()
    if on_quit then
      on_quit()
    else
      M.close()
    end
  end, { buffer = buf, nowait = true })

  dots = 1
  render()

  stop_timer()
  timer = uv.new_timer()
  timer:start(TICK_MS, TICK_MS, function()
    vim.schedule(function()
      if not valid() then
        M.close()
        return
      end
      dots = dots % 3 + 1
      render()
    end)
  end)
end

function M.close()
  stop_timer()
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  win = nil
  buf = nil
  dots = 1
  on_quit = nil
end

return M
