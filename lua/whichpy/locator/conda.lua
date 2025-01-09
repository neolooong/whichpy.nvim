local util = require("whichpy.util")
local is_win = util.is_win
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_conda_info = require("whichpy.locator._common").get_conda_info
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

local Locator = {
  name = "conda",
  display_name = "Conda",
  get_env_var_strategy = get_env_var_strategy.conda,
}

function Locator:find()
  local conda_info = get_conda_info()

  return coroutine.wrap(function()
    if not conda_info then
      return
    end

    for _, env in ipairs(conda_info.envs) do
      local path = get_interpreter_path(env, is_win and "root" or "bin")
      if vim.uv.fs_stat(path) then
        coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
      end
    end
  end)
end

return Locator
