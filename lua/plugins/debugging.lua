return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      {
        "<leader>dx",
        function()
          require("dap").clear_breakpoints()
        end,
        desc = "Clear All Breakpoints",
      },
    },
  },
}
