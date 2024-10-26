local M = {}

M.locators = {}

---@param opts WhichPy.Config
M.setup = function(opts)
  require("whichpy.config").setup_config(opts or {})
  require("whichpy.envs").asearch(true)
  -- Create User Command
  require("whichpy.usercmd").create_user_cmd()
end

return M
