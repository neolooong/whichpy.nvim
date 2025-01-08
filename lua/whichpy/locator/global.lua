local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_search_path_entries = require("whichpy.locator._common").get_search_path_entries

local Locator = {
  name = "global",
  display_name = "Global",
  get_env_var = get_env_var_strategy.guess,
}

function Locator:find()
  return coroutine.wrap(function()
    local dirs = get_search_path_entries()

    for _, dir in ipairs(dirs) do
      local interpreter_path = get_interpreter_path(dir, "root")
      if vim.uv.fs_stat(interpreter_path) then
        coroutine.yield({ locator = self, interpreter_path = interpreter_path })
      end
    end
  end)
end

return Locator
