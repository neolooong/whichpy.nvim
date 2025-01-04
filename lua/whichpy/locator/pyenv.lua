local util = require("whichpy.util")
local is_win = util.is_win
local get_interpreter_path = util.get_interpreter_path

local get_pyenv_version_dir = function()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return vim.fs.joinpath(pyenv_root, "versions")
end

local Locator = { name = "pyenv", display_name = "Pyenv" }

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

function Locator:determine_env_var(path)
  local venv = vim.fs.dirname(vim.fs.dirname(path))
  local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
  if vim.uv.fs_stat(pyvenv_cfg) then
    return "VIRTUAL_ENV", venv
  end
  return nil, nil
end

return Locator
