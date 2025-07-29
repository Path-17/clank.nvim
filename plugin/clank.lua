vim.api.nvim_create_user_command("ClankHello", function()
  require("clank").hello()
end, {})
