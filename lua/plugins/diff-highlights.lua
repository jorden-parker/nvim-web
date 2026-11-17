return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      word_diff = true,
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = function()
      local diff_highlights = require("diff_highlights")
      diff_highlights.setup()
      Snacks.toggle({
        name = "Diff Highlights",
        get = diff_highlights.is_shown,
        set = diff_highlights.show,
      }):map("<leader>uH")
    end,
  },
}
