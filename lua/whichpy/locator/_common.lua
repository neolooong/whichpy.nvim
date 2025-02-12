local util = require("whichpy.util")
local is_win = util.is_win
local config = require("whichpy.config").config

local M = {}

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
  local exclude_path
  if config.update_path_env then
    local selected_path = require("whichpy.envs").current_selected()
    if selected_path ~= nil then
      exclude_path = vim.fs.dirname(selected_path)
    end
  end
  dirs = vim
    .iter(dirs)
    :filter(function(dir)
      return dir ~= pyenv_shims
        and (exclude_path == nil or exclude_path ~= nil and dir ~= exclude_path)
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

function M.get_workspace_folders()
  local hash = {}
  local res = {}
  for lsp_name, _ in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client ~= nil and client.config ~= nil and client.config.workspace_folders ~= nil then
      for _, val in ipairs(client.config.workspace_folders) do
        if hash[val.name] == nil then
          hash[val.name] = true
          table.insert(res, val.name)
        end
      end
    end
  end
  if #res > 0 then
    return res
  end
  table.insert(res, vim.fs.root(0, { "pyproject.toml", "setup.py", ".git" }) or vim.fn.getcwd())
  return res
end

M.get_env_var_strategy = {}

function M.get_env_var_strategy.no()
  return {}
end

function M.get_env_var_strategy.conda(python_path)
  local prefix = vim.fs.dirname(python_path)
  if not is_win then
    prefix = vim.fs.dirname(prefix)
  end
  return { name = "CONDA_PREFIX", val = prefix }
end

function M.get_env_var_strategy.pyenv(python_path)
  local venv = vim.fs.dirname(vim.fs.dirname(python_path))
  local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
  if vim.uv.fs_stat(pyvenv_cfg) then
    return { name = "VIRTUAL_ENV", val = venv }
  end
  return {}
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
