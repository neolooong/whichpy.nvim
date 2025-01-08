local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_pyenv_version_dir = require("whichpy.locator._common").get_pyenv_version_dir

local Locator = {
  name = "pyenv",
  display_name = "Pyenv",
  get_env_var = get_env_var_strategy.virtual_env,
}

function Locator:find()
  return coroutine.wrap(function()
    local dir = get_pyenv_version_dir()

    for name, t in vim.fs.dir(dir) do
      if t == "directory" then
        local interpreter_path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
        if vim.uv.fs_stat(interpreter_path) then
          coroutine.yield({ locator = self, interpreter_path = interpreter_path })

          local envs_dir = vim.fs.joinpath(dir, name, "envs")

          ---@diagnostic disable-next-line: redefined-local
          for name, t in vim.fs.dir(envs_dir) do
            if t == "directory" then
              interpreter_path = get_interpreter_path(vim.fs.joinpath(envs_dir, name), "bin")
              if vim.uv.fs_stat(interpreter_path) then
                coroutine.yield({ locator = self, interpreter_path = interpreter_path })
              end
            end
          end
        end
      end
    end
  end)
end

return Locator
