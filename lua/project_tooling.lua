local project_tooling = {}

local default_formatter = "oxfmt"

local formatters_by_precedence = {
  {
    name = "oxfmt",
    config_files = { ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts" },
    package_names = { "oxfmt", "vite-plus" },
  },
  {
    name = "biome-check",
    config_files = { "biome.json", "biome.jsonc" },
    package_names = {},
  },
  {
    name = "prettier",
    config_files = {
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.json5",
      ".prettierrc.yaml",
      ".prettierrc.yml",
      ".prettierrc.toml",
      ".prettierrc.js",
      ".prettierrc.cjs",
      ".prettierrc.mjs",
      ".prettierrc.ts",
      ".prettierrc.cts",
      ".prettierrc.mts",
      "prettier.config.js",
      "prettier.config.cjs",
      "prettier.config.mjs",
      "prettier.config.ts",
      "prettier.config.cts",
      "prettier.config.mts",
    },
    package_names = { "prettier" },
  },
}

local oxlint_config_files = { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" }
local oxlint_package_names = { "oxlint", "vite-plus" }

local function is_existing_file(file_path)
  local file_status = vim.uv.fs_stat(file_path)
  return file_status ~= nil and file_status.type == "file"
end

local function has_any_file(directory, file_names)
  for _, file_name in ipairs(file_names) do
    if is_existing_file(vim.fs.joinpath(directory, file_name)) then
      return true
    end
  end
  return false
end

local function read_package_manifest(directory)
  local manifest_file = io.open(vim.fs.joinpath(directory, "package.json"), "r")
  if not manifest_file then
    return nil
  end
  local manifest_text = manifest_file:read("*a")
  manifest_file:close()
  return manifest_text
end

local function has_package_mention(directory, package_names)
  if #package_names == 0 then
    return false
  end
  local manifest_text = read_package_manifest(directory)
  if not manifest_text then
    return false
  end
  for _, package_name in ipairs(package_names) do
    if manifest_text:find('"' .. package_name .. '"', 1, true) then
      return true
    end
  end
  return false
end

local function is_configured_in(directory, config_files, package_names)
  return has_any_file(directory, config_files) or has_package_mention(directory, package_names)
end

local function walk_directories_upward(start_directory)
  local is_start_pending = true
  local next_parent = vim.fs.parents(start_directory)
  local current_directory = start_directory
  return function()
    if is_start_pending then
      is_start_pending = false
      return start_directory
    end
    current_directory = next_parent(nil, current_directory)
    return current_directory
  end
end

local function find_nearest_directory_configured_with(start_directory, config_files, package_names)
  for directory in walk_directories_upward(start_directory) do
    if is_configured_in(directory, config_files, package_names) then
      return directory
    end
  end
  return nil
end

function project_tooling.choose_formatter_for(start_directory)
  for directory in walk_directories_upward(start_directory) do
    for _, formatter in ipairs(formatters_by_precedence) do
      if is_configured_in(directory, formatter.config_files, formatter.package_names) then
        return formatter.name
      end
    end
  end
  return default_formatter
end

function project_tooling.find_oxlint_root(file_path)
  local file_directory = vim.fs.dirname(file_path)
  local repository_root = vim.fs.root(file_directory, ".git")
  if repository_root and has_any_file(repository_root, oxlint_config_files) then
    return repository_root
  end
  return find_nearest_directory_configured_with(file_directory, oxlint_config_files, {})
    or find_nearest_directory_configured_with(file_directory, {}, oxlint_package_names)
end

return project_tooling
