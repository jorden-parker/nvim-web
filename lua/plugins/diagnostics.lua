local function show_message_only(diagnostic)
  return diagnostic.message
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        virtual_text = false,
        virtual_lines = {
          current_line = true,
          format = show_message_only,
        },
      },
    },
  },
}
