local common = require("whichpy.locator._common")
local get_env_var_strategy = common.get_env_var_strategy

---@class WhichPy.Locator.Uv: WhichPy.Locator

---@class WhichPy.Locator.Uv.Opts

local Locator = { name = "uv" }
Locator.__index = Locator

---@param opts? WhichPy.Locator.Uv.Opts
---@return WhichPy.Locator.Uv
function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "uv",
    get_env_var_strategy = get_env_var_strategy.no,
  }, opts or {})
  return setmetatable(obj, Locator)
end

---@param Job WhichPy.SearchJob
---@return fun(): WhichPy.Ctx|WhichPy.InterpreterInfo
function Locator:find(Job)
  return common.async_find({
    locator = self,
    Job = Job,
    cmd = { "uv", "python", "dir" },
    parse_output = function(stdout)
      local dir = vim.trim(stdout)
      return dir ~= "" and dir or nil
    end,
    err_msg = "uv command error",
    find_fn = common.find_interpreters_in_dir,
  })
end

return Locator
