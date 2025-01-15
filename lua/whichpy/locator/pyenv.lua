local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_pyenv_version_dir = require("whichpy.locator._common").get_pyenv_version_dir
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---@class WhichPy.Locator.Pyenv: WhichPy.Locator

---@class WhichPy.Locator.Pyenv.Opts

local Locator = {name = "pyenv"}
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "Pyenv",
    get_env_var_strategy = get_env_var_strategy.virtual_env,
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find()
  return coroutine.wrap(function()
    local dir = get_pyenv_version_dir()

    for name, t in vim.fs.dir(dir) do
      if t == "directory" then
        local path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
        if vim.uv.fs_stat(path) then
          coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))

          local envs_dir = vim.fs.joinpath(dir, name, "envs")

          ---@diagnostic disable-next-line: redefined-local
          for name, t in vim.fs.dir(envs_dir) do
            if t == "directory" then
              path = get_interpreter_path(vim.fs.joinpath(envs_dir, name), "bin")
              if vim.uv.fs_stat(path) then
                coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
              end
            end
          end
        end
      end
    end
  end)
end

return Locator
