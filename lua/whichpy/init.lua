local M = {}

---@param opts WhichPy.Config
M.setup = function(opts)
  require("whichpy.config").setup_config(opts or {})
  require("whichpy.usercmd").create_user_cmd()
  require("whichpy.lsp").create_autocmd()
  require("whichpy.envs").retrieve_cache()
end

return M
