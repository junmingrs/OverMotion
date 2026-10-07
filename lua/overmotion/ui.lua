local M = {}

function M.build()
  vim.cmd('enew')
  local edit_buf = vim.api.nvim_get_current_buf()
  local edit_win = vim.api.nvim_get_current_win()

  -- target buffer: top 5 lines, horizontal split
  vim.cmd('topleft 5split')
  local target_win = vim.api.nvim_get_current_win()
  local target_buf = vim.api.nvim_get_current_buf()

  -- leaderboard: left 10%, vertical split
  vim.cmd('topleft vsplit')
  local board_win = vim.api.nvim_get_current_win()
  local board_buf = vim.api.nvim_get_current_buf()
  local width = math.floor(vim.o.columns * 0.1)
  vim.api.nvim_win_set_width(board_win, width)

  vim.api.nvim_set_current_win(edit_win)

  for _, buf in ipairs({ target_buf, board_buf }) do
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
  end
  vim.wo[target_win].number = false
  vim.wo[target_win].relativenumber = false
  vim.wo[board_win].number = false
  vim.wo[board_win].relativenumber = false
  vim.bo[edit_buf].buftype = 'nofile'
  vim.bo[edit_buf].swapfile = false

  return {
    target_buf = target_buf,
    target_win = target_win,
    board_buf = board_buf,
    board_win = board_win,
    edit_buf = edit_buf,
    edit_win = edit_win,
  }
end

function M.set_target(target_buf, text)
  vim.bo[target_buf].modifiable = true
  vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { '-- ' .. text })
  vim.bo[target_buf].modifiable = false
end

return M
