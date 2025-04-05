local M = {}

---@param opts WhichPy.Config
M.setup = function(opts)
  local config = require("whichpy.config")
  config.setup_config(opts or {})
  require("whichpy.usercmd").create_user_cmd()
  require("whichpy.lsp").create_autocmd()

  if config.config.set_env_on_startup then
    if vim.v.vim_did_enter == 0 then
      M._augroup = vim.api.nvim_create_augroup("WhichPyStartup", { clear = true })
      vim.api.nvim_create_autocmd({ "VimEnter" }, {
        group = M._augroup,
        callback = function()
        require("whichpy.envs").retrieve_cache()
        end
      })
    else
      require("whichpy.envs").retrieve_cache()
    end
  end
end

return M
