local fallback_base_branch = "origin/main"

local function open_pull_request_of_current_branch()
  vim.system(
    { "gh", "pr", "view", "--json", "number", "--jq", ".number" },
    { text = true },
    vim.schedule_wrap(function(command_result)
      local pull_request_number = vim.trim(command_result.stdout or "")
      if command_result.code ~= 0 or pull_request_number == "" then
        vim.notify("No pull request found for the current branch", vim.log.levels.WARN)
        return
      end
      vim.cmd("Octo pr edit " .. pull_request_number)
    end)
  )
end

local function resolve_base_branch()
  local command_result = vim.system({ "git", "rev-parse", "--abbrev-ref", "origin/HEAD" }, { text = true }):wait()
  local remote_default_branch = vim.trim(command_result.stdout or "")
  if command_result.code == 0 and remote_default_branch ~= "" then
    return remote_default_branch
  end
  return fallback_base_branch
end

local function diff_branch_against_base()
  vim.cmd("DiffviewOpen " .. resolve_base_branch() .. "...HEAD --imply-local")
end

local function show_branch_commits()
  vim.cmd("DiffviewFileHistory --range=" .. resolve_base_branch() .. "..HEAD")
end

return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>p", group = "pull requests", icon = { icon = " ", color = "green" } },
      },
    },
  },

  {
    "pwntester/octo.nvim",
    keys = {
      { "<leader>pl", "<cmd>Octo pr list<cr>", desc = "List Open Pull Requests" },
      { "<leader>ps", "<cmd>Octo pr search<cr>", desc = "Search Pull Requests" },
      {
        "<leader>pm",
        "<cmd>Octo search is:pr is:open review-requested:@me<cr>",
        desc = "Pull Requests Awaiting My Review",
      },
      { "<leader>pa", "<cmd>Octo search is:pr is:open author:@me<cr>", desc = "My Open Pull Requests" },
      { "<leader>pp", open_pull_request_of_current_branch, desc = "Open Pull Request of Current Branch" },
      { "<leader>pn", "<cmd>Octo pr create<cr>", desc = "New Pull Request From Current Branch" },
      { "<leader>po", "<cmd>Octo pr checkout<cr>", desc = "Check Out This Pull Request" },
      { "<leader>pb", "<cmd>Octo pr browser<cr>", desc = "Open Pull Request in Browser" },
      { "<leader>pk", "<cmd>Octo pr checks<cr>", desc = "Show Pull Request Checks" },
      { "<leader>pr", "<cmd>Octo review start<cr>", desc = "Start Review" },
      { "<leader>pR", "<cmd>Octo review resume<cr>", desc = "Resume Pending Review" },
      { "<leader>pS", "<cmd>Octo review submit<cr>", desc = "Submit Review" },
      { "<leader>pD", "<cmd>Octo review discard<cr>", desc = "Discard Pending Review" },
      { "<leader>pt", "<cmd>Octo review comments<cr>", desc = "Show Pending Review Comments" },
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    opts = {
      enhanced_diff_hl = true,
    },
    keys = {
      { "<leader>pv", diff_branch_against_base, desc = "Diff Branch Against Base (Diffview)" },
      { "<leader>ph", show_branch_commits, desc = "Branch Commit History (Diffview)" },
      { "<leader>pf", "<cmd>DiffviewFileHistory %<cr>", desc = "Current File History (Diffview)" },
      { "<leader>pq", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    },
  },
}
