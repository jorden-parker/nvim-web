local function show_hover_with_type_definition()
  require("type_hover").show()
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, options)
      local keys_for_every_server = options.servers["*"].keys
      table.insert(keys_for_every_server, { "K", show_hover_with_type_definition, desc = "Hover With Type Definition" })
    end,
  },
}
