local set_keymap = vim.keymap.set

local function copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  vim.notify("Copied " .. text)
end

local function copy_relative_file_path()
  copy_to_clipboard(vim.fn.expand("%:."))
end

local function copy_absolute_file_path()
  copy_to_clipboard(vim.fn.expand("%:p"))
end

local function open_nearest_package_manifest()
  local buffer_directory = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local manifest_path = vim.fs.find("package.json", { upward = true, path = buffer_directory })[1]
  if not manifest_path then
    vim.notify("No package.json found above this file", vim.log.levels.WARN)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(manifest_path))
end

local replace_word_under_cursor = [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]]

set_keymap("i", "jj", "<Esc>", { desc = "Exit Insert Mode" })
set_keymap("i", "jk", "<Esc>", { desc = "Exit Insert Mode" })
set_keymap("n", "<leader>fy", copy_relative_file_path, { desc = "Copy Relative File Path" })
set_keymap("n", "<leader>fY", copy_absolute_file_path, { desc = "Copy Absolute File Path" })
set_keymap("n", "<leader>fj", open_nearest_package_manifest, { desc = "Open Nearest package.json" })
set_keymap("n", "<leader>cw", replace_word_under_cursor, { desc = "Replace Word Under Cursor in File" })
