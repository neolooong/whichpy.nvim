local get_interpreter_path = require("whichpy.util").get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local InterpreterInfo = require("whichpy.locator").InterpreterInfo
local get_workspace_folders = require("whichpy.locator._common").get_workspace_folders

---@class WhichPy.Locator.Workspace: WhichPy.Locator
---@field depth integer
---@field search_pattern string
---@field ignore_dirs string[]

---@class WhichPy.Locator.Workspace.Opts
---@field depth? integer
---@field search_pattern? string
---@field ignore_dirs? string[]

local Locator = { name = "workspace" }
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "Workspace",
    get_env_var_strategy = get_env_var_strategy.virtual_env,
    search_pattern = ".*env.*",
    depth = 2,
    ignore_dirs = {
      ".git",
      ".mypy_cache",
      ".pytest_cache",
      ".ruff_cache",
      "__pycache__",
      "__pypackages__",
    },
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find()
  local dirs = vim
    .iter(get_workspace_folders())
    :map(function(dir)
      return { dir, 1 }
    end)
    :totable()

  return coroutine.wrap(function()
    while #dirs > 0 do
      local dir, depth = unpack(table.remove(dirs, 1))
      local fs = vim.uv.fs_scandir(dir)
      while fs do
        local name, t = vim.uv.fs_scandir_next(fs)
        if not name then
          break
        end
        if t == "directory" then
          local path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")

          if not vim.list_contains(self.ignore_dirs, name) then
            if name:match(self.search_pattern) and vim.uv.fs_stat(path) then
              coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
            elseif depth < self.depth then
              dirs[#dirs + 1] = { vim.fs.joinpath(dir, name), depth + 1 }
            end
          end
        end
      end
    end
  end)
end

return Locator
