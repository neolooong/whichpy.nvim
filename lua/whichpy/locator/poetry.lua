local get_interpreter_path = require("whichpy.util").get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_poetry_virtualenvs_path = require("whichpy.locator._common").get_poetry_virtualenvs_path
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

local Locator = {
  name = "poetry",
  display_name = "Poetry",
  get_env_var_strategy = get_env_var_strategy.virtual_env,
}

function Locator:find()
  local dir = get_poetry_virtualenvs_path()

  return coroutine.wrap(function()
    if not dir then
      return
    end

    for name, t in vim.fs.dir(dir) do
      if t == "directory" then
        local path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
        if vim.uv.fs_stat(path) then
          coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
        end
      end
    end
  end)
end

return Locator
