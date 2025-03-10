local M = {}

---@param opts WhichPy.Config
M.setup = function(opts)
  require("whichpy.config").setup_config(opts or {})
  require("whichpy.usercmd").create_user_cmd()
  require("whichpy.lsp").create_autocmd()

  M._augroup = vim.api.nvim_create_augroup("WhichPyStartup", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = M._augroup,
    callback = function()
      require("whichpy.envs").retrieve_cache()
    end
  })
end

return M
