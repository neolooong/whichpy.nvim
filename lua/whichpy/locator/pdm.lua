local common = require("whichpy.locator._common")
local get_env_var_strategy = common.get_env_var_strategy

---@class WhichPy.Locator.Pdm: WhichPy.Locator

---@class WhichPy.Locator.Pdm.Opts

local Locator = { name = "pdm" }
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "PDM",
    get_env_var_strategy = get_env_var_strategy.virtual_env,
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find(Job)
  return common.async_find({
    locator = self,
    Job = Job,
    cmd = { "pdm", "config", "venv.location" },
    parse_output = function(stdout)
      local dir = vim.trim(stdout)
      return dir ~= "" and dir or nil
    end,
    err_msg = "pdm command error",
    find_fn = common.find_interpreters_in_dir,
  })
end

return Locator
