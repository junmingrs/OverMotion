local M = {}

local transport = require('overmotion.transport')
local protocol = require('overmotion.protocol')
local tracker = require('overmotion.tracker')
local solve = require('overmotion.solve')
local client_ui = require('overmotion.client_ui')
local waiting = require('overmotion.waiting')

local state = nil
local generation = 0

local function close_intermission()
  if not state then
    return
  end
  local win, buf = state.end_win, state.end_buf
  state.end_win = nil
  state.end_buf = nil
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

local function clear_game()
  if not state or not state.wins then
    return
  end
  local wins = state.wins
  state.wins = nil
  state.edit_buf = nil
  for _, buf in ipairs({ wins.target_buf, wins.edit_buf }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  for _, win in ipairs({ wins.target_win, wins.edit_win }) do
    if win and vim.api.nvim_win_is_valid(win) and #vim.api.nvim_list_wins() > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

local function leave()
  if not state then
    require('overmotion.starter').show()
    return
  end
  local s = state
  close_intermission()
  tracker.detach()
  clear_game()
  state = nil
  generation = generation + 1
  waiting.close()
  if s.conn then
    s.conn.close()
  end
  require('overmotion.starter').show()
end

local function handle_solved()
  if not state or state.awaiting then
    return
  end
  if solve.buffer_matches(state.edit_buf, state.target) then
    state.awaiting = true
    state.solved_count = state.solved_count + 1
    local keystrokes = tracker.count()
    local elapsed_ms = tracker.elapsed_ms()
    state.total_keystrokes = state.total_keystrokes + keystrokes
    state.conn.send(protocol.encode({
      type = 'solved',
      id = state.prompt_id,
      elapsed_ms = elapsed_ms,
      keystrokes = keystrokes,
    }))
  end
end

local function load_prompt(msg)
  if not state.wins then
    state.wins = client_ui.match_layout()
    state.edit_buf = state.wins.edit_buf
    tracker.attach(state.wins.edit_win)
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      buffer = state.edit_buf,
      callback = handle_solved,
    })
    vim.keymap.set('n', 'q', leave, { buffer = state.edit_buf, nowait = true })
  end

  state.target = msg.target
  state.prompt_id = msg.id
  state.awaiting = false
  tracker.reset()

  vim.bo[state.wins.target_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.wins.target_buf, 0, -1, false, { msg.target })
  vim.bo[state.wins.target_buf].modifiable = false
  vim.api.nvim_buf_set_lines(state.edit_buf, 0, -1, false, { msg.broken })
  vim.api.nvim_win_set_cursor(state.wins.edit_win, { 1, 0 })
  vim.cmd('stopinsert')
end

local function open_intermission(msg)
  if not state then
    return
  end

  local width = 52
  local function center(line)
    local pad = math.max(0, math.floor((width - #line) / 2))
    return string.rep(' ', pad) .. line
  end
  local function short_name(name)
    name = name or ''
    if #name > 12 then
      return name:sub(1, 9) .. '...'
    end
    return name
  end
  local function whole(n)
    return math.floor((tonumber(n) or 0) + 0.5)
  end

  local you = msg.you or {}
  local points = whole(you.points)
  local solved = you.solved or state.solved_count
  local keystrokes = you.keystrokes or state.total_keystrokes
  local avg_seconds = you.avg_seconds or 0

  local lines = {
    '',
    center('MATCH OVER'),
    '',
    center(string.format('Your points: %d', points)),
    center(string.format('Solved this round: %d', solved)),
    center(string.format('Total keystrokes:  %d', keystrokes)),
    center(string.format('Average per solve: %.2fs', avg_seconds)),
    '',
    center('TOP 3'),
  }
  local scores = msg.scores or {}
  if #scores == 0 then
    table.insert(lines, center('—'))
  else
    for i, entry in ipairs(scores) do
      if i > 3 then
        break
      end
      table.insert(lines, center(string.format(
        '%d. %-12s %4d pts',
        i,
        short_name(entry.name),
        whole(entry.points)
      )))
    end
  end
  table.insert(lines, '')
  table.insert(lines, center('Waiting for next round...'))
  table.insert(lines, '')
  table.insert(lines, '  [q] Leave')

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false

  local height = math.min(#lines, math.max(1, vim.o.lines - 4))
  local ok, win = pcall(vim.api.nvim_open_win, buf, true, {
    relative = 'editor',
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = 'minimal',
    border = 'single',
  })
  if not ok then
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    return
  end

  vim.wo[win].cursorline = true
  state.end_buf = buf
  state.end_win = win
  vim.keymap.set('n', 'q', leave, { buffer = buf, nowait = true })
end

local function on_message(msg)
  if msg.type == 'start' then
    if not state then
      return
    end
    close_intermission()
    state.solved_count = 0
    state.total_keystrokes = 0
    state.awaiting = true
    state.target = nil
    state.prompt_id = nil
    vim.notify(string.format('Match started! %ds', math.floor((msg.duration_ms or 0) / 1000)))
  elseif msg.type == 'joined' then
    if state then
      waiting.open(state.host, leave)
    end
  elseif msg.type == 'prompt' then
    if not state then
      return
    end
    close_intermission()
    waiting.close()
    load_prompt(msg)
  elseif msg.type == 'end' then
    if not state then
      return
    end
    close_intermission()
    waiting.close()
    vim.notify('Match over!')
    tracker.detach()
    clear_game()
    state.awaiting = true
    state.target = nil
    state.prompt_id = nil
    open_intermission(msg)
  end
end

function M.start()
  client_ui.connect_form(function(name, host, port)
    if state then
      leave()
    end
    generation = generation + 1
    local my_generation = generation
    local function current()
      return state ~= nil and generation == my_generation
    end

    state = {
      conn = nil,
      wins = nil,
      target = nil,
      prompt_id = nil,
      awaiting = false,
      solved_count = 0,
      total_keystrokes = 0,
      name = name,
      host = host,
      port = port,
      end_win = nil,
      end_buf = nil,
    }

    state.conn = transport.connect(host, port, function(line)
      if not current() then
        return
      end
      local msg = protocol.decode(line)
      if msg then
        on_message(msg)
      end
    end, function(err)
      if not current() then
        return
      end
      vim.notify('Connection error: ' .. tostring(err), vim.log.levels.ERROR)
      leave()
    end, function()
      if not current() then
        return
      end
      vim.notify('Disconnected from server')
      leave()
    end, function()
      if current() and state.conn then
        state.conn.send(protocol.encode({ type = 'join', name = name }))
      end
    end)
  end)
end

return M
