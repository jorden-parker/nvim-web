local diff_highlights = {}

local namespace = vim.api.nvim_create_namespace("diff_highlights_in_files")
local priority_below_syntax_highlighting = 50
local is_shown = true
local last_known_hunks_by_buffer = {}

local line_highlights_by_hunk_type = {
  add = "DiffAdd",
  change = "DiffChange",
}

local changed_word_highlight_links = {
  GitSignsAddLnInline = "DiffText",
  GitSignsChangeLnInline = "DiffText",
  GitSignsDeleteLnInline = "DiffDelete",
}

---Gitsigns forgets a buffer's hunks on every edit and computes them again a
---moment later. The previous hunks are used in between so the colours do not
---flicker while typing.
local function get_hunks_of(buffer)
  local gitsigns_buffer = require("gitsigns.cache").cache[buffer]
  if not gitsigns_buffer then
    last_known_hunks_by_buffer[buffer] = nil
    return {}
  end
  if gitsigns_buffer.hunks then
    last_known_hunks_by_buffer[buffer] = gitsigns_buffer.hunks
  end
  return last_known_hunks_by_buffer[buffer] or {}
end

local function highlight_visible_lines_of(hunk, buffer, top_row, bottom_row)
  local line_highlight = line_highlights_by_hunk_type[hunk.type]
  local first_row = math.max(hunk.added.start - 1, top_row)
  local last_row = math.min(hunk.added.start + hunk.added.count - 2, bottom_row)
  if not line_highlight or first_row > last_row then
    return
  end
  vim.api.nvim_buf_set_extmark(buffer, namespace, first_row, 0, {
    end_row = last_row + 1,
    end_col = 0,
    hl_group = line_highlight,
    hl_eol = true,
    priority = priority_below_syntax_highlighting,
    ephemeral = true,
    strict = false,
  })
end

---Paints the added and changed lines a window shows with the diff colours.
---Runs on every redraw, so it always matches the hunks gitsigns knows about.
---The sign column's own line highlight is not used because it covers the
---highlight of the changed words inside a line.
local function highlight_window(_, _, buffer, top_row, bottom_row)
  if not is_shown or not package.loaded["gitsigns"] then
    return false
  end
  for _, hunk in ipairs(get_hunks_of(buffer)) do
    highlight_visible_lines_of(hunk, buffer, top_row, bottom_row)
  end
  return false
end

local function link_changed_word_highlights()
  for highlight_group, diff_group in pairs(changed_word_highlight_links) do
    vim.api.nvim_set_hl(0, highlight_group, { link = diff_group })
  end
end

local function forget_hunks_of_wiped_buffer(event)
  last_known_hunks_by_buffer[event.buf] = nil
end

function diff_highlights.setup()
  local autocommand_group = vim.api.nvim_create_augroup("diff_highlights_in_files", { clear = true })
  link_changed_word_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { group = autocommand_group, callback = link_changed_word_highlights })
  vim.api.nvim_create_autocmd("BufWipeout", { group = autocommand_group, callback = forget_hunks_of_wiped_buffer })
  vim.api.nvim_set_decoration_provider(namespace, { on_win = highlight_window })
end

function diff_highlights.is_shown()
  return is_shown
end

function diff_highlights.show(should_show)
  is_shown = should_show
  require("gitsigns.config").config.word_diff = should_show
  vim.cmd("redraw!")
end

return diff_highlights
