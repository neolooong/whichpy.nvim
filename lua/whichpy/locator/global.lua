local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_search_path_entries = require("whichpy.locator._common").get_search_path_entries
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

local Locator = {
  name = "global",
  display_name = "Global",
  get_env_var_strategy = get_env_var_strategy.guess,
}

function Locator:find()
  return coroutine.wrap(function()
    local dirs = get_search_path_entries()

    for _, dir in ipairs(dirs) do
      local path = get_interpreter_path(dir, "root")
      if vim.uv.fs_stat(path) then
        coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
      end
    end
  end)
end

return Locator
