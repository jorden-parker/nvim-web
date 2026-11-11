local project_tooling = require("project_tooling")

local additional_oxfmt_filetypes = {
  "css",
  "scss",
  "less",
  "html",
  "handlebars",
  "markdown",
  "markdown.mdx",
  "yaml",
  "toml",
  "graphql",
  "json5",
}

local function when_project_formats_with(formatter_name)
  return function(_, context)
    return project_tooling.choose_formatter_for(context.dirname) == formatter_name
  end
end

local function run_oxfmt_first_for(formatters_by_filetype, filetype)
  local formatters = formatters_by_filetype[filetype] or {}
  if not vim.tbl_contains(formatters, "oxfmt") then
    table.insert(formatters, 1, "oxfmt")
  end
  formatters_by_filetype[filetype] = formatters
end

local function attach_oxlint_to_project_root(buffer, on_dir)
  local oxlint_root = project_tooling.find_oxlint_root(vim.api.nvim_buf_get_name(buffer))
  if oxlint_root then
    on_dir(oxlint_root)
  end
end

local function get_whole_buffer_range()
  local last_line_number = vim.api.nvim_buf_line_count(0)
  local last_line = vim.api.nvim_buf_get_lines(0, last_line_number - 1, last_line_number, false)[1] or ""
  return { start = { 1, 0 }, ["end"] = { last_line_number, #last_line } }
end

local function apply_to_whole_buffer(code_action_kind)
  return function()
    vim.lsp.buf.code_action({
      apply = true,
      context = { only = { code_action_kind }, diagnostics = {} },
      range = get_whole_buffer_range(),
    })
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        oxlint = {
          root_dir = attach_oxlint_to_project_root,
          keys = {
            { "<leader>cx", apply_to_whole_buffer("source.fixAll.oxc"), desc = "Fix All Safely (Oxlint)" },
            {
              "<leader>cX",
              apply_to_whole_buffer("source.fixAllDangerous.oxc"),
              desc = "Fix All Including Unsafe Fixes (Oxlint)",
            },
          },
        },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    opts = function(_, options)
      options.formatters_by_ft = options.formatters_by_ft or {}
      for _, filetype in ipairs(additional_oxfmt_filetypes) do
        run_oxfmt_first_for(options.formatters_by_ft, filetype)
      end

      options.formatters = options.formatters or {}
      local is_prettier_able_to_parse = (options.formatters.prettier or {}).condition
      local is_prettier_project = when_project_formats_with("prettier")

      options.formatters.oxfmt = { condition = when_project_formats_with("oxfmt") }
      options.formatters["biome-check"] = {
        require_cwd = true,
        condition = when_project_formats_with("biome-check"),
      }
      options.formatters.prettier = {
        condition = function(formatter, context)
          if not is_prettier_project(formatter, context) then
            return false
          end
          return is_prettier_able_to_parse == nil or is_prettier_able_to_parse(formatter, context)
        end,
      }
    end,
  },
}
