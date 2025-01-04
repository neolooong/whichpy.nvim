local util = require("whichpy.util")
local is_win = util.is_win
local get_interpreter_path = util.get_interpreter_path

local common_posix_bin_paths = {
  "/bin",
  "/etc",
  "/lib",
  "/lib/x86_64-linux-gnu",
  "/lib64",
  "/sbin",
  "/snap/bin",
  "/usr/bin",
  "/usr/games",
  "/usr/include",
  "/usr/lib",
  "/usr/lib/x86_64-linux-gnu",
  "/usr/lib64",
  "/usr/libexec",
  "/usr/local",
  "/usr/local/bin",
  "/usr/local/etc",
  "/usr/local/games",
  "/usr/local/lib",
  "/usr/local/sbin",
  "/usr/sbin",
  "/usr/share",
  "~/.local/bin",
}

local get_pyenv_shims_dir = function()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return vim.fs.joinpath(pyenv_root, "shims")
end

local get_pyenv_version_dir = function()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return vim.fs.joinpath(pyenv_root, "versions")
end

local get_search_path_entries = function()
  local delimiter = (is_win and ";") or ":"
  local dirs = vim.split(vim.env.PATH or vim.env.Path, delimiter)
  if not is_win then
    dirs = vim.list_extend(dirs, common_posix_bin_paths)
  end
  local pyenv_shims = get_pyenv_shims_dir()
  return vim
    .iter(dirs)
    :filter(function(dir)
      return dir ~= pyenv_shims
    end)
    :map(function(dir)
      return vim.fn.fnamemodify(dir, ":p")
    end)
    :totable()
end

local Locator = { name = "global", display_name = "Global" }

function Locator:find()
  return coroutine.wrap(function()
    local dirs = util.deduplicate(get_search_path_entries())

    for _, dir in ipairs(dirs) do
      local interpreter_path = get_interpreter_path(dir, "root")
      if vim.uv.fs_stat(interpreter_path) then
        coroutine.yield({ locator = self, interpreter_path = interpreter_path })
      end
    end
  end)
end

function Locator:determine_env_var(path)
  local venv = vim.fs.dirname(vim.fs.dirname(path))
  if vim.startswith(path, get_pyenv_version_dir()) then
    local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
    if vim.uv.fs_stat(pyvenv_cfg) then
      return "VIRTUAL_ENV", venv
    end
    return nil, nil
  end

  local prefix = vim.fs.dirname(path)
  if not is_win then
    prefix = vim.fs.dirname(prefix)
  end
  local conda_meta = vim.fs.joinpath(prefix, "conda-meta")
  if vim.uv.fs_stat(conda_meta) then
    return "CONDA_PREFIX", prefix
  end

  local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
  if vim.uv.fs_stat(pyvenv_cfg) then
    return "VIRTUAL_ENV", venv
  end
  return nil, nil
end

return Locator
