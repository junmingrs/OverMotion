local M = {}

local transport = require('overmotion.transport')
local protocol = require('overmotion.protocol')
local tracker = require('overmotion.tracker')
local solve = require('overmotion.solve')
local client_ui = require('overmotion.client_ui')

local state = nil

local function handle_solved()
  if not state or state.awaiting then
    return
  end
  if solve.buffer_matches(state.edit_buf, state.target) then
    state.awaiting = true
    state.conn.send(protocol.encode({
      type = 'solved',
      id = state.prompt_id,
      elapsed_ms = tracker.elapsed_ms(),
      keystrokes = tracker.count(),
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
    vim.keymap.set('n', 'q', function()
      state.conn.close()
      tracker.detach()
      state = nil
    end, { buffer = state.edit_buf, nowait = true })
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
end

local function on_message(msg)
  if msg.type == 'start' then
    vim.notify(string.format('Match started! %ds', math.floor((msg.duration_ms or 0) / 1000)))
  elseif msg.type == 'prompt' then
    load_prompt(msg)
  elseif msg.type == 'end' then
    vim.notify('Match over!')
    if state and state.conn then
      state.conn.close()
    end
    tracker.detach()
  end
end

function M.start()
  client_ui.connect_form(function(name, host, port)
    state = { conn = nil, wins = nil, target = nil, prompt_id = nil, awaiting = false }
    state.conn = transport.connect(host, port, function(line)
      local msg = protocol.decode(line)
      if msg then
        on_message(msg)
      end
    end, function(err)
      vim.notify('Connection error: ' .. tostring(err), vim.log.levels.ERROR)
    end, function()
      vim.notify('Disconnected from server')
    end)
    state.conn.send(protocol.encode({ type = 'join', name = name }))
  end)
end

return M
