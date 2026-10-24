local M = {}

local DEFAULT_HOST = '16.176.140.127'
local DEFAULT_PORT = 7777

function M.connect_form(on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    '  OverClient',
    '',
    '  Name: ',
    '',
    '  Press Enter in normal mode',
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local width = 40
  local height = #lines
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
  })
  vim.bo[buf].bufhidden = 'wipe'
  vim.wo[win].cursorline = true

  local function submit()
    local name
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      name = name or line:match('^%s*Name:%s*(.-)%s*$')
    end
    if not name or name == '' then
      vim.notify('Enter a name', vim.log.levels.WARN)
      return
    end
    vim.api.nvim_win_close(win, true)
    on_submit(name, DEFAULT_HOST, DEFAULT_PORT)
  end

  vim.keymap.set('n', '<CR>', submit, { buffer = buf })
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  vim.api.nvim_win_set_cursor(win, { 3, 8 })
  vim.cmd('stopinsert')
end

function M.match_layout()
  vim.cmd('enew')
  local edit_buf = vim.api.nvim_get_current_buf()
  local edit_win = vim.api.nvim_get_current_win()

  vim.cmd('topleft 3split')
  local target_win = vim.api.nvim_get_current_win()
  local target_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(target_win, target_buf)
  vim.api.nvim_set_current_win(edit_win)

  vim.bo[target_buf].buftype = 'nofile'
  vim.bo[target_buf].modifiable = false
  vim.bo[target_buf].bufhidden = 'wipe'
  vim.bo[target_buf].swapfile = false
  vim.wo[target_win].number = false
  vim.wo[target_win].relativenumber = false
  vim.bo[edit_buf].swapfile = false

  return { target_buf = target_buf, target_win = target_win, edit_buf = edit_buf, edit_win = edit_win }
end

return M
