local util = require("whichpy.util")
local is_win = util.is_win
local asystem = require("whichpy.async").asystem

local M = {}

function M.get_conda_info()
  local ok, res = asystem({ "conda", "info", "--json" }, {})

  if ok and res.code == 0 then
    return vim.json.decode(res.stdout)
  end
end

function M.get_pdm_venv_location()
  local ok, res = asystem({ "pdm", "config", "venv.location" }, {})
  if ok and res.code == 0 then
    return vim.trim(res.stdout)
  end
end

function M.get_poetry_virtualenvs_path()
  local ok, res = asystem({ "poetry", "config", "virtualenvs.path" }, {})
  if ok and res.code == 0 then
    return vim.trim(res.stdout)
  end
end

function M.get_pyenv_dir()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return pyenv_root
end

function M.get_pyenv_version_dir()
  return vim.fs.joinpath(M.get_pyenv_dir(), "versions")
end

function M.get_pyenv_shims_dir()
  return vim.fs.joinpath(M.get_pyenv_dir(), "shims")
end

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

function M.get_search_path_entries()
  local delimiter = (is_win and ";") or ":"
  local dirs = vim.split(vim.env.PATH or vim.env.Path, delimiter)
  if not is_win then
    dirs = vim.list_extend(dirs, common_posix_bin_paths)
  end
  local pyenv_shims = M.get_pyenv_shims_dir()
  dirs = vim
    .iter(dirs)
    :filter(function(dir)
      return dir ~= pyenv_shims
    end)
    :map(function(dir)
      return vim.fn.fnamemodify(dir, ":p")
    end)
    :totable()
  return util.deduplicate(dirs)
end

function M.get_global_virtual_environment_dirs(opts_dirs)
  local sysname = vim.uv.os_uname().sysname
  local dirs = {}
  for _, value in ipairs(opts_dirs) do
    if type(value) == "string" then
      dirs[#dirs + 1] = vim.fn.fnamemodify(value, ":p")
    else
      local dir, dir_sysname = unpack(value)
      if dir_sysname == "ALL" or dir_sysname == sysname then
        dirs[#dirs + 1] = vim.fn.fnamemodify(dir, ":p")
      end
    end
  end
  return util.deduplicate(dirs)
end

M.get_env_var_strategy = {}

function M.get_env_var_strategy.conda_prefix(python_path)
  local prefix = vim.fs.dirname(python_path)
  if not is_win then
    prefix = vim.fs.dirname(prefix)
  end
  return { name = "CONDA_PREFIX", val = prefix }
end

function M.get_env_var_strategy.virtual_env(python_path)
  return { name = "VIRTUAL_ENV", val = vim.fs.dirname(vim.fs.dirname(python_path)) }
end

function M.get_env_var_strategy.guess(python_path)
  local venv = vim.fs.dirname(vim.fs.dirname(python_path))
  if vim.startswith(python_path, M.get_pyenv_version_dir()) then
    local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
    if vim.uv.fs_stat(pyvenv_cfg) then
      return { name = "VIRTUAL_ENV", val = venv }
    end
    return {}
  end

  local prefix = vim.fs.dirname(python_path)
  if not is_win then
    prefix = vim.fs.dirname(prefix)
  end
  local conda_meta = vim.fs.joinpath(prefix, "conda-meta")
  if vim.uv.fs_stat(conda_meta) then
    return { name = "CONDA_PREFIX", val = prefix }
  end

  local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
  if vim.uv.fs_stat(pyvenv_cfg) then
    return { name = "VIRTUAL_ENV", val = venv }
  end
  return {}
end

return M
