local M = {}

function M.connect(host, port, on_line, on_error, on_close)
  local uv = vim.uv
  local handle = uv.new_tcp()
  local buffer = ''

  local function process_buffer()
    while true do
      local nl = buffer:find('\n', 1, true)
      if not nl then
        break
      end
      local line = buffer:sub(1, nl - 1)
      buffer = buffer:sub(nl + 1)
      if #line > 0 then
        vim.schedule(function()
          on_line(line)
        end)
      end
    end
  end

  handle:connect(host, port, function(err)
    if err then
      vim.schedule(function()
        on_error(err)
      end)
      return
    end
    handle:read_start(function(read_err, chunk)
      if read_err then
        vim.schedule(function()
          on_error(read_err)
        end)
        return
      end
      if not chunk then
        vim.schedule(function()
          on_close()
        end)
        return
      end
      buffer = buffer .. chunk
      process_buffer()
    end)
  end)

  return {
    send = function(line)
      handle:write(line .. '\n')
    end,
    close = function()
      handle:read_stop()
      handle:close()
    end,
  }
end

return M
