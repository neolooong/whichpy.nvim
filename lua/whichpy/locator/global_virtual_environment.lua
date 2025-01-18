local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_global_virtual_environment_dirs =
  require("whichpy.locator._common").get_global_virtual_environment_dirs
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---@class WhichPy.Locator.GlobalVirtualEnvironment: WhichPy.Locator
---@field dirs (string|{[1]: string, [2]: string})[]

---@class WhichPy.Locator.GlobalVirtualEnvironment.Opts
---@field dirs? (string|{[1]: string, [2]: string})[]

local Locator = { name = "global_virtual_environment" }
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "Global Virtual Environemnt",
    get_env_var_strategy = get_env_var_strategy.virtual_env,
    dirs = {
      "~/envs",
      "~/.direnv",
      "~/.venvs",
      "~/.virtualenvs",
      "~/.local/share/virtualenvs",
      { "~/Envs", "Windows_NT" },
      vim.env.WORKON_HOME,
    },
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find()
  return coroutine.wrap(function()
    local dirs = get_global_virtual_environment_dirs(self.dirs)

    while #dirs > 0 do
      local dir = table.remove(dirs, 1)
      local fs = vim.uv.fs_scandir(dir)
      while fs do
        local name, t = vim.uv.fs_scandir_next(fs)
        if not name then
          break
        end
        if t == "directory" then
          local path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
          if vim.uv.fs_stat(path) then
            coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
          end
        end
      end
    end
  end)
end

return Locator
