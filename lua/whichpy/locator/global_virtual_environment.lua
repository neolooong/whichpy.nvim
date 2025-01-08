local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_global_virtual_environment_dirs =
  require("whichpy.locator._common").get_global_virtual_environment_dirs

local _opts = {}

local Locator = {
  name = "global_virtual_environment",
  display_name = "Global Virtual Environemnt",
  get_env_var = get_env_var_strategy.guess,
}

function Locator.merge_opts(opts)
  _opts = vim.tbl_deep_extend("force", _opts, opts or {})
end

function Locator:find()
  return coroutine.wrap(function()
    local dirs = get_global_virtual_environment_dirs(_opts.dirs)

    while #dirs > 0 do
      local dir = table.remove(dirs, 1)
      local fs = vim.uv.fs_scandir(dir)
      while fs do
        local name, t = vim.uv.fs_scandir_next(fs)
        if not name then
          break
        end
        if t == "directory" then
          local interpreter_path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
          if vim.uv.fs_stat(interpreter_path) then
            coroutine.yield({ locator = self, interpreter_path = interpreter_path })
          end
        end
      end
    end
  end)
end

return Locator
