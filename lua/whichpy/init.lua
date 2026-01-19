local M = {}

---@param opts WhichPy.Config
M.setup = function(opts)
  require("whichpy.config").setup_config(opts or {})
  require("whichpy.usercmd").create_user_cmd()
  require("whichpy.lsp").create_autocmd()

  -- Commands that emit output should wait until startup is complete
  -- to ensure notifications etc are set up.
  if vim.v.vim_did_enter == 0 then
    M._augroup = vim.api.nvim_create_augroup("WhichPyStartup", { clear = true })
    vim.api.nvim_create_autocmd({ "UIEnter" }, {
      group = M._augroup,
      callback = function()
        vim.defer_fn(function()
          require("whichpy.envs").retrieve_cache()
        end, 200)
      end,
    })
  else
    require("whichpy.envs").retrieve_cache()
  end
end

return M
