local repository_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = repository_root .. "/lua/?.lua;" .. repository_root .. "/tests/?.lua;" .. package.path

local checks = require("support.checks")
local project_tooling = require("project_tooling")

local function create_project(files)
  local project_directory = vim.uv.fs_realpath(vim.fn.tempname() .. "-project") or (vim.fn.tempname() .. "-project")
  for relative_path, content in pairs(files) do
    local absolute_path = vim.fs.joinpath(project_directory, relative_path)
    vim.fn.mkdir(vim.fs.dirname(absolute_path), "p")
    vim.fn.writefile(vim.split(content, "\n"), absolute_path)
  end
  vim.fn.mkdir(project_directory, "p")
  return vim.uv.fs_realpath(project_directory)
end

checks.check("oxfmt is the formatter when no project config exists", function()
  local project_directory = create_project({ ["src/example.ts"] = "" })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory .. "/src"), "oxfmt")
end)

checks.check("an oxfmt config file selects oxfmt", function()
  local project_directory = create_project({ [".oxfmtrc.json"] = "{}", [".prettierrc"] = "{}" })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory), "oxfmt")
end)

checks.check("a prettier config file selects prettier", function()
  local project_directory = create_project({ ["prettier.config.mjs"] = "export default {}", ["src/example.ts"] = "" })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory .. "/src"), "prettier")
end)

checks.check("a biome config file selects biome-check", function()
  local project_directory = create_project({ ["biome.jsonc"] = "{}" })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory), "biome-check")
end)

checks.check("an oxfmt dependency in package.json selects oxfmt", function()
  local project_directory = create_project({
    ["package.json"] = '{ "devDependencies": { "oxfmt": "^0.78.0", "prettier": "^3.0.0" } }',
  })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory), "oxfmt")
end)

checks.check("a prettier key in package.json selects prettier", function()
  local project_directory = create_project({ ["package.json"] = '{ "prettier": { "semi": false } }' })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory), "prettier")
end)

checks.check("the nearest config wins over one further up", function()
  local project_directory = create_project({
    [".prettierrc"] = "{}",
    ["packages/storefront/.oxfmtrc.json"] = "{}",
    ["packages/storefront/src/example.ts"] = "",
    ["packages/legacy/src/example.ts"] = "",
  })
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory .. "/packages/storefront/src"), "oxfmt")
  checks.expect_equal(project_tooling.choose_formatter_for(project_directory .. "/packages/legacy/src"), "prettier")
end)

checks.check("the oxlint root is the repository-level config in a monorepo", function()
  local project_directory = create_project({
    [".git/HEAD"] = "ref: refs/heads/main",
    [".oxlintrc.json"] = "{}",
    ["packages/storefront/.oxlintrc.json"] = "{}",
    ["packages/storefront/src/example.ts"] = "",
  })
  checks.expect_equal(
    project_tooling.find_oxlint_root(project_directory .. "/packages/storefront/src/example.ts"),
    project_directory
  )
end)

checks.check("the oxlint root is the nearest config when the repository root has none", function()
  local project_directory = create_project({
    [".git/HEAD"] = "ref: refs/heads/main",
    ["packages/storefront/oxlint.config.ts"] = "export default {}",
    ["packages/storefront/src/example.ts"] = "",
  })
  checks.expect_equal(
    project_tooling.find_oxlint_root(project_directory .. "/packages/storefront/src/example.ts"),
    project_directory .. "/packages/storefront"
  )
end)

checks.check("the oxlint root falls back to a package.json that depends on oxlint", function()
  local project_directory = create_project({
    ["package.json"] = '{ "devDependencies": { "oxlint": "^1.93.0" } }',
    ["src/example.ts"] = "",
  })
  checks.expect_equal(project_tooling.find_oxlint_root(project_directory .. "/src/example.ts"), project_directory)
end)

checks.check("there is no oxlint root in a project that does not use oxlint", function()
  local project_directory = create_project({
    ["package.json"] = '{ "devDependencies": { "eslint": "^9.0.0" } }',
    ["src/example.ts"] = "",
  })
  checks.expect_equal(project_tooling.find_oxlint_root(project_directory .. "/src/example.ts"), nil)
end)

checks.finish()
