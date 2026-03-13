local util = require("whichpy.util")
local is_win = util.is_win
local get_interpreter_path = util.get_interpreter_path
local common = require("whichpy.locator._common")
local get_env_var_strategy = common.get_env_var_strategy
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---@class WhichPy.Locator.Conda: WhichPy.Locator

---@class WhichPy.Locator.Conda.Opts

local Locator = { name = "conda" }
Locator.__index = Locator

---@param opts? WhichPy.Locator.Conda.Opts
---@return WhichPy.Locator.Conda
function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "Conda",
    get_env_var_strategy = get_env_var_strategy.conda,
  }, opts or {})
  return setmetatable(obj, Locator)
end

---@param Job WhichPy.SearchJob
---@return fun(): WhichPy.Ctx|WhichPy.InterpreterInfo
function Locator:find(Job)
  return common.async_find({
    locator = self,
    Job = Job,
    cmd = { "conda", "info", "--json" },
    parse_output = function(stdout)
      local ok, result = pcall(vim.json.decode, stdout)
      if not ok then
        return nil
      end
      return result.envs
    end,
    err_msg = "conda command error",
    find_fn = function(locator, envs)
      return coroutine.wrap(function()
        for _, env in ipairs(envs) do
          local path = get_interpreter_path(env, is_win and "root" or "bin")
          if vim.uv.fs_stat(path) then
            coroutine.yield(InterpreterInfo:new({ locator = locator, path = path }))
          end
        end
      end)
    end,
  })
end

return Locator
