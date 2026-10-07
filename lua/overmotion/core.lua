local M = {}

local sentences = require('overmotion.sentences')
local tracker = require('overmotion.tracker')
local leaderboard = require('overmotion.leaderboard')
local ui = require('overmotion.ui')

local state = nil

local function normalize(s)
  s = s:gsub('%s+', ' ')
  return vim.trim(s)
end

local function teardown()
  tracker.detach()
  for _, buf in ipairs({ state.target_buf, state.board_buf, state.edit_buf }) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  state = nil
end

local function check()
  if not state then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(state.edit_buf, 0, -1, false)
  local content = normalize(table.concat(lines, ' '))
  if content == normalize(state.current) and #content > 0 then
    leaderboard.add({
      sentence = state.current,
      keystrokes = tracker.count(),
      elapsed_ms = tracker.elapsed_ms(),
    })
    leaderboard.render(state.board_buf)
    vim.notify(string.format('Solved in %d keystrokes!', tracker.count()), vim.log.levels.INFO)
    M.next()
  end
end

function M.next()
  state.current = sentences.random()
  ui.set_target(state.target_buf, state.current)
  vim.api.nvim_buf_set_lines(state.edit_buf, 0, -1, false, { '' })
  tracker.reset()
end

function M.start()
  math.randomseed(os.time())
  leaderboard.load()
  state = ui.build()
  tracker.attach(state.edit_win)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = state.edit_buf,
    callback = check,
  })
  vim.keymap.set('n', 'r', function()
    vim.api.nvim_buf_set_lines(state.edit_buf, 0, -1, false, { '' })
  end, { buffer = state.edit_buf, nowait = true })
  vim.keymap.set('n', 's', function()
    M.next()
  end, { buffer = state.edit_buf, nowait = true })
  vim.keymap.set('n', 'q', function()
    teardown()
  end, { buffer = state.edit_buf, nowait = true })
  leaderboard.render(state.board_buf)
  M.next()
end

return M
