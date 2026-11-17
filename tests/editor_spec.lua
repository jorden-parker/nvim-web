local repository_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = repository_root .. "/lua/?.lua;" .. repository_root .. "/tests/?.lua;" .. package.path

local checks = require("support.checks")
local terminal_editor = require("support.terminal_editor")

local fixtures_directory = repository_root .. "/tests/fixtures"
local oxc_project = fixtures_directory .. "/oxc-project"

local startup_timeout_milliseconds = 10 * 60 * 1000
local tool_install_timeout_milliseconds = 15 * 60 * 1000
local language_server_timeout_milliseconds = 90 * 1000
local edit_timeout_milliseconds = 30 * 1000

local expected_mason_packages = {
  "oxlint",
  "oxfmt",
  "vtsls",
  "prettier",
  "biome",
  "eslint-lsp",
  "html-lsp",
  "css-lsp",
  "emmet-language-server",
  "json-lsp",
  "yaml-language-server",
  "tailwindcss-language-server",
  "marksman",
  "markdownlint-cli2",
}

local expected_treesitter_parsers = {
  "typescript",
  "tsx",
  "javascript",
  "jsdoc",
  "html",
  "css",
  "scss",
  "json",
  "json5",
  "yaml",
  "markdown",
  "markdown_inline",
  "graphql",
}

local expected_plugins = {
  "LazyVim",
  "conform.nvim",
  "nvim-lspconfig",
  "mason.nvim",
  "nvim-treesitter",
  "octo.nvim",
  "diffview.nvim",
  "gitsigns.nvim",
  "claudecode.nvim",
}

local pull_request_review_keys = {
  "<leader>pl",
  "<leader>ps",
  "<leader>pm",
  "<leader>pa",
  "<leader>pp",
  "<leader>pn",
  "<leader>po",
  "<leader>pb",
  "<leader>pk",
  "<leader>pr",
  "<leader>pR",
  "<leader>pS",
  "<leader>pD",
  "<leader>pt",
  "<leader>pv",
  "<leader>ph",
  "<leader>pf",
  "<leader>pq",
  "<leader>gp",
  "<leader>gP",
}

local claude_code_normal_mode_keys = {
  "<leader>ac",
  "<leader>af",
  "<leader>ar",
  "<leader>aC",
  "<leader>ab",
  "<leader>aa",
  "<leader>ad",
}

local claude_code_visual_mode_keys = { "<leader>as" }

local everyday_normal_mode_keys = {
  "<leader>fy",
  "<leader>fY",
  "<leader>fj",
  "<leader>cw",
}

local everyday_insert_mode_keys = { "jj", "jk" }

local has_key_mapping_source = [[
  local mode, key = ...
  local expanded_key = key:gsub("<leader>", vim.g.mapleader)
  return vim.fn.maparg(expanded_key, mode) ~= ""
]]

local visible_problems_source = [[
  local message_from_test_terminal_without_emulator = "E1568"
  local problems = {}
  for _, message_line in ipairs(vim.split(vim.fn.execute("messages"), "\n", { trimempty = true })) do
    local is_error_message = message_line:match("^E%d+:") ~= nil or message_line:lower():find("error", 1, true) ~= nil
    if is_error_message and not message_line:find(message_from_test_terminal_without_emulator, 1, true) then
      table.insert(problems, message_line)
    end
  end
  for _, notification in ipairs(Snacks.notifier.get_history()) do
    if notification.level == "error" or notification.level == "warn" then
      table.insert(problems, notification.msg)
    end
  end
  return problems
]]

local has_finished_startup_source = [[
  return vim.v.vim_did_enter == 1 and vim.g.did_very_lazy == true
]]

local has_attached_client_source = [[
  return #vim.lsp.get_clients({ bufnr = 0, name = ... }) > 0
]]

local buffer_contains_source = [[
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find(..., 1, true) ~= nil
]]

local record_clipboard_source = [[
  local function record_copied_lines(lines)
    _G.recorded_clipboard_lines = lines
  end
  local function paste_recorded_lines()
    return { _G.recorded_clipboard_lines or {}, "v" }
  end
  vim.g.clipboard = {
    name = "recorder",
    copy = { ["+"] = record_copied_lines, ["*"] = record_copied_lines },
    paste = { ["+"] = paste_recorded_lines, ["*"] = paste_recorded_lines },
  }
  vim.g.loaded_clipboard_provider = nil
  vim.cmd("runtime autoload/provider/clipboard.vim")
]]

local formatter_names_source = [[
  local formatter_names = {}
  for _, formatter in ipairs(require("conform").list_formatters_to_run(0)) do
    table.insert(formatter_names, formatter.name)
  end
  return formatter_names
]]

local function start_editor_in(working_directory)
  local editor = terminal_editor.start(working_directory)
  editor.wait_until("startup finishes", has_finished_startup_source, startup_timeout_milliseconds)
  return editor
end

local function install_tooling()
  local editor = start_editor_in(oxc_project)
  editor.open_file(oxc_project .. "/src/lint-target.ts")
  editor.wait_until(
    "Mason installs every web tool",
    [[
      local registry = require("mason-registry")
      for _, package_name in ipairs(...) do
        if not registry.is_installed(package_name) then
          return false
        end
      end
      return true
    ]],
    tool_install_timeout_milliseconds,
    expected_mason_packages
  )
  editor.wait_until(
    "Tree-sitter installs every web parser",
    [[
      local installed_parsers = require("nvim-treesitter").get_installed()
      for _, parser_name in ipairs(...) do
        if not vim.tbl_contains(installed_parsers, parser_name) then
          return false
        end
      end
      return true
    ]],
    tool_install_timeout_milliseconds,
    expected_treesitter_parsers
  )
  editor.stop()
end

local function list_formatter_names_for(editor, file_path)
  editor.open_file(file_path)
  return editor.evaluate(formatter_names_source)
end

checks.check("the first launch installs plugins, Mason tools and Tree-sitter parsers", install_tooling)

local editor = start_editor_in(oxc_project)

checks.check("the editor starts without errors or warnings", function()
  checks.expect_equal(editor.evaluate(visible_problems_source), {})
end)

checks.check("every plugin is installed", function()
  local missing_plugins = editor.evaluate([[
    local missing_plugins = {}
    for _, plugin in ipairs(require("lazy").plugins()) do
      if not plugin._.installed then
        table.insert(missing_plugins, plugin.name)
      end
    end
    return missing_plugins
  ]])
  checks.expect_equal(missing_plugins, {})
end)

checks.check("the web development and review plugins are part of the config", function()
  local absent_plugins = editor.evaluate(
    [[
      local plugin_names = {}
      for _, plugin in ipairs(require("lazy").plugins()) do
        plugin_names[plugin.name] = true
      end
      local absent_plugins = {}
      for _, expected_name in ipairs(...) do
        if not plugin_names[expected_name] then
          table.insert(absent_plugins, expected_name)
        end
      end
      return absent_plugins
    ]],
    expected_plugins
  )
  checks.expect_equal(absent_plugins, {})
end)

checks.check("the pull request review keys are mapped", function()
  for _, key in ipairs(pull_request_review_keys) do
    checks.expect_equal({ key, editor.evaluate(has_key_mapping_source, "n", key) }, { key, true })
  end
end)

checks.check("the Claude Code keys are mapped", function()
  for _, key in ipairs(claude_code_normal_mode_keys) do
    checks.expect_equal({ key, editor.evaluate(has_key_mapping_source, "n", key) }, { key, true })
  end
  for _, key in ipairs(claude_code_visual_mode_keys) do
    checks.expect_equal({ key, editor.evaluate(has_key_mapping_source, "x", key) }, { key, true })
  end
end)

checks.check("the everyday keys are mapped", function()
  for _, key in ipairs(everyday_normal_mode_keys) do
    checks.expect_equal({ key, editor.evaluate(has_key_mapping_source, "n", key) }, { key, true })
  end
  for _, key in ipairs(everyday_insert_mode_keys) do
    checks.expect_equal({ key, editor.evaluate(has_key_mapping_source, "i", key) }, { key, true })
  end
end)

checks.check("<leader>fy copies the file path relative to the project", function()
  editor.open_file(oxc_project .. "/src/format-target.ts")
  editor.evaluate(record_clipboard_source)
  editor.type_keys("<Space>fy")
  editor.wait_until(
    "the relative path is copied",
    [[return vim.deep_equal(_G.recorded_clipboard_lines, { "src/format-target.ts" })]],
    edit_timeout_milliseconds
  )
end)

checks.check("<leader>fY copies the absolute file path", function()
  editor.type_keys("<Space>fY")
  editor.wait_until(
    "the absolute path is copied",
    [[return vim.deep_equal(_G.recorded_clipboard_lines, { ... })]],
    edit_timeout_milliseconds,
    oxc_project .. "/src/format-target.ts"
  )
end)

checks.check("<leader>cw replaces the word under the cursor in the whole file", function()
  editor.evaluate([[vim.fn.search("greeting")]])
  editor.type_keys("<Space>cw")
  editor.wait_until("the substitute command is prepared", [[return vim.fn.mode() == "c"]], edit_timeout_milliseconds)
  editor.type_keys("<C-w>salutation<CR>")
  editor.wait_until("the word is replaced", buffer_contains_source, edit_timeout_milliseconds, "salutation")
  checks.expect_equal(editor.evaluate(buffer_contains_source, "greeting"), false)
  editor.evaluate([[vim.cmd("edit!")]])
end)

checks.check("<leader>fj opens the nearest package.json", function()
  editor.type_keys("<Space>fj")
  editor.wait_until(
    "package.json is open",
    [[return vim.api.nvim_buf_get_name(0) == ...]],
    edit_timeout_milliseconds,
    oxc_project .. "/package.json"
  )
end)

checks.check("the review plugins load without errors", function()
  editor.evaluate([[require("lazy").load({ plugins = { "octo.nvim", "diffview.nvim" } })]])
  checks.expect_equal(
    editor.evaluate([[return vim.fn.exists(":Octo") == 2 and vim.fn.exists(":DiffviewOpen") == 2]]),
    true
  )
  checks.expect_equal(editor.evaluate(visible_problems_source), {})
end)

checks.check("the Claude Code plugin loads without errors", function()
  editor.evaluate([[require("lazy").load({ plugins = { "claudecode.nvim" } })]])
  checks.expect_equal(
    editor.evaluate([[return vim.fn.exists(":ClaudeCode") == 2 and vim.fn.exists(":ClaudeCodeDiffAccept") == 2]]),
    true
  )
  checks.expect_equal(editor.evaluate(visible_problems_source), {})
end)

checks.check("oxlint reports diagnostics through its language server", function()
  editor.open_file(oxc_project .. "/src/lint-target.ts")
  editor.wait_until("oxlint attaches", has_attached_client_source, language_server_timeout_milliseconds, "oxlint")
  editor.wait_until(
    "oxlint reports the debugger statement",
    [[
      for _, diagnostic in ipairs(vim.diagnostic.get(0)) do
        if diagnostic.message:lower():find("debugger", 1, true) then
          return true
        end
      end
      return false
    ]],
    language_server_timeout_milliseconds
  )
end)

checks.check("<leader>cx applies only the safe oxlint fixes", function()
  editor.type_keys("<Space>cx")
  editor.wait_until("var becomes const", buffer_contains_source, edit_timeout_milliseconds, "const cartLabel")
  checks.expect_equal(editor.evaluate(buffer_contains_source, "productCount == 0"), true)
end)

checks.check("<leader>cX also applies the unsafe oxlint fixes", function()
  editor.type_keys("<Space>cX")
  editor.wait_until(
    "loose equality becomes strict",
    buffer_contains_source,
    edit_timeout_milliseconds,
    "productCount === 0"
  )
end)

checks.check("the TypeScript language server attaches", function()
  editor.wait_until("vtsls attaches", has_attached_client_source, language_server_timeout_milliseconds, "vtsls")
end)

checks.check("<leader>cf formats TypeScript with oxfmt and the project's oxfmt config", function()
  checks.expect_equal(list_formatter_names_for(editor, oxc_project .. "/src/format-target.ts"), { "oxfmt" })
  editor.type_keys("<Space>cf")
  editor.wait_until(
    "the buffer is formatted",
    [[return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "export const greeting = 'hello'"]],
    edit_timeout_milliseconds
  )
  checks.expect_equal(editor.read_buffer_lines(), {
    "export const greeting = 'hello'",
    "export function greet(visitorName: string) {",
    "  return greeting + ', ' + visitorName",
    "}",
  })
end)

checks.check("oxfmt formats CSS, HTML, JSON, YAML and Markdown in an Oxc project", function()
  for _, relative_path in ipairs({ "src/styles.css", "src/page.html", "src/settings.json", "src/content.yaml" }) do
    checks.expect_equal(
      { relative_path, list_formatter_names_for(editor, oxc_project .. "/" .. relative_path) },
      { relative_path, { "oxfmt" } }
    )
  end
  checks.expect_equal(list_formatter_names_for(editor, oxc_project .. "/docs/notes.md")[1], "oxfmt")
end)

checks.check("oxfmt rewrites a CSS buffer", function()
  editor.open_file(oxc_project .. "/src/styles.css")
  editor.type_keys("<Space>cf")
  editor.wait_until(
    "the stylesheet is formatted",
    [[return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == ".card {"]],
    edit_timeout_milliseconds
  )
  checks.expect_equal(editor.read_buffer_lines(), { ".card {", "  color: red;", "  margin: 0;", "}" })
end)

checks.check("a Prettier project is formatted with prettier only", function()
  checks.expect_equal(
    list_formatter_names_for(editor, fixtures_directory .. "/prettier-project/src/example.ts"),
    { "prettier" }
  )
end)

checks.check("a Biome project is formatted with biome only", function()
  checks.expect_equal(
    list_formatter_names_for(editor, fixtures_directory .. "/biome-project/src/example.ts"),
    { "biome-check" }
  )
end)

checks.check("the HTML, CSS and JSON language servers attach", function()
  local servers_by_file = {
    ["src/page.html"] = "html",
    ["src/styles.css"] = "cssls",
    ["src/settings.json"] = "jsonls",
  }
  for relative_path, server_name in pairs(servers_by_file) do
    editor.open_file(oxc_project .. "/" .. relative_path)
    editor.wait_until(
      server_name .. " attaches",
      has_attached_client_source,
      language_server_timeout_milliseconds,
      server_name
    )
  end
end)

checks.check("no errors or warnings were shown during the session", function()
  checks.expect_equal(editor.evaluate(visible_problems_source), {})
end)

editor.stop()
checks.finish()
