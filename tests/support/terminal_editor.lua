local terminal_editor = {}

local nanoseconds_per_millisecond = 1000000
local poll_interval_milliseconds = 250
local connect_timeout_milliseconds = 30 * 1000
local exit_timeout_milliseconds = 5000
local terminal_columns = 160
local terminal_rows = 50

local function get_current_milliseconds()
  return vim.uv.hrtime() / nanoseconds_per_millisecond
end

local function connect_to(socket_path)
  local deadline = get_current_milliseconds() + connect_timeout_milliseconds
  while get_current_milliseconds() < deadline do
    local is_connected, channel = pcall(vim.fn.sockconnect, "pipe", socket_path, { rpc = true })
    if is_connected and channel > 0 then
      return channel
    end
    vim.uv.sleep(poll_interval_milliseconds)
  end
  error("could not connect to the editor at " .. socket_path)
end

function terminal_editor.start(working_directory)
  local socket_path = vim.fn.tempname() .. ".sock"
  local terminal_job = vim.fn.jobstart({ vim.v.progpath, "--listen", socket_path }, {
    pty = true,
    width = terminal_columns,
    height = terminal_rows,
    cwd = working_directory,
    env = { TERM = "xterm-256color" },
  })
  local channel = connect_to(socket_path)

  local editor = {}

  function editor.evaluate(lua_source, ...)
    return vim.rpcrequest(channel, "nvim_exec_lua", lua_source, { ... })
  end

  function editor.type_keys(keys)
    vim.rpcrequest(channel, "nvim_input", keys)
  end

  function editor.wait_until(description, predicate_source, timeout_milliseconds, ...)
    local deadline = get_current_milliseconds() + timeout_milliseconds
    while get_current_milliseconds() < deadline do
      if editor.evaluate(predicate_source, ...) == true then
        return
      end
      vim.uv.sleep(poll_interval_milliseconds)
    end
    error("timed out waiting until " .. description, 2)
  end

  function editor.open_file(file_path)
    editor.evaluate("vim.cmd.edit(vim.fn.fnameescape(...))", file_path)
  end

  function editor.read_buffer_lines()
    return editor.evaluate("return vim.api.nvim_buf_get_lines(0, 0, -1, false)")
  end

  function editor.stop()
    pcall(vim.rpcnotify, channel, "nvim_command", "qall!")
    vim.fn.jobwait({ terminal_job }, exit_timeout_milliseconds)
    vim.fn.jobstop(terminal_job)
  end

  return editor
end

return terminal_editor
