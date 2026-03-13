local common = require("whichpy.locator._common")
local get_env_var_strategy = common.get_env_var_strategy

---@class WhichPy.Locator.Poetry: WhichPy.Locator

---@class WhichPy.Locator.Poetry.Opts

local Locator = { name = "poetry" }
Locator.__index = Locator

---@param opts? WhichPy.Locator.Poetry.Opts
---@return WhichPy.Locator.Poetry
function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "Poetry",
    get_env_var_strategy = get_env_var_strategy.virtual_env,
  }, opts or {})
  return setmetatable(obj, Locator)
end

---@param Job WhichPy.SearchJob
---@return fun(): WhichPy.Ctx|WhichPy.InterpreterInfo
function Locator:find(Job)
  return common.async_find({
    locator = self,
    Job = Job,
    cmd = { "poetry", "config", "virtualenvs.path" },
    parse_output = function(stdout)
      local dir = vim.trim(stdout)
      return dir ~= "" and dir or nil
    end,
    err_msg = "poetry command error",
    find_fn = common.find_interpreters_in_dir,
  })
end

return Locator
