local M = {}

M.setup = function(opts)
  require("whichpy.config").setup_config(opts or {})

  local config = require("whichpy.config").config
  for locator_name, locator_opts in pairs(config.locator) do
    local locator = require("whichpy.locator")[locator_name]
    if locator ~= nil then
      if locator.merge_opts then
        locator.merge_opts(locator_opts)
      end
    end
  end

  require("whichpy.envs").asearch(true)

  -- Create User Command
  require("whichpy.usercmd").create_user_cmd()
end

return M
