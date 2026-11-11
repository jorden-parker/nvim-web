local stylesheet_settings = {
  validate = true,
  lint = { unknownAtRules = "ignore" },
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {},
        cssls = {
          settings = {
            css = stylesheet_settings,
            scss = stylesheet_settings,
            less = stylesheet_settings,
          },
        },
        emmet_language_server = {},
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "css",
        "scss",
        "graphql",
        "json5",
      },
    },
  },
}
