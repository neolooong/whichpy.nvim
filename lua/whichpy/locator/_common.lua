local util = require("whichpy.util")
local is_win = util.is_win
local config = require("whichpy.config").config

local M = {}

---@return string
function M.get_pyenv_dir()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return pyenv_root
end

---@return string
function M.get_pyenv_version_dir()
  return vim.fs.joinpath(M.get_pyenv_dir(), "versions")
end

---@return string
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

---@return string[]
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
      return dir ~= pyenv_shims and (exclude_path == nil or dir ~= exclude_path)
    end)
    :map(function(dir)
      return vim.fn.fnamemodify(dir, ":p")
    end)
    :totable()
  return util.deduplicate(dirs)
end

---@param opts_dirs (string|string[])[]
---@return string[]
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

---@return string[]
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

---@type table<string, fun(python_path?: string): WhichPy.EnvVar>
M.get_env_var_strategy = {}

---@return WhichPy.EnvVar
function M.get_env_var_strategy.no()
  return {}
end

---@param python_path string
---@return WhichPy.EnvVar
function M.get_env_var_strategy.conda(python_path)
  local prefix = vim.fs.dirname(python_path)
  if not is_win then
    prefix = vim.fs.dirname(prefix)
  end
  return { name = "CONDA_PREFIX", val = prefix }
end

---@param python_path string
---@return WhichPy.EnvVar
function M.get_env_var_strategy.pyenv(python_path)
  local venv = vim.fs.dirname(vim.fs.dirname(python_path))
  local pyvenv_cfg = vim.fs.joinpath(venv, "pyvenv.cfg")
  if vim.uv.fs_stat(pyvenv_cfg) then
    return { name = "VIRTUAL_ENV", val = venv }
  end
  return {}
end

---@param python_path string
---@return WhichPy.EnvVar
function M.get_env_var_strategy.virtual_env(python_path)
  return { name = "VIRTUAL_ENV", val = vim.fs.dirname(vim.fs.dirname(python_path)) }
end

---@param python_path string
---@return WhichPy.EnvVar
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

---@class WhichPy.AsyncFindOpts
---@field locator WhichPy.Locator
---@field Job WhichPy.SearchJob
---@field cmd string[]
---@field parse_output fun(stdout: string): any?
---@field err_msg string
---@field find_fn fun(locator: WhichPy.Locator, data: any): fun(): WhichPy.InterpreterInfo?

---Shared async find pattern for locators that run an external command.
---@param opts WhichPy.AsyncFindOpts
---@return fun(): WhichPy.Ctx|WhichPy.InterpreterInfo
function M.async_find(opts)
  return coroutine.wrap(function()
    if vim.fn.executable(opts.cmd[1]) == 0 then
      return
    end

    vim.system(opts.cmd, { timeout = 10000 }, function(out)
      local ctx = { locator_name = opts.locator.name }

      if out.code ~= 0 then
        ctx.err = opts.err_msg
      else
        local data = opts.parse_output(out.stdout)
        if data then
          ctx.co = function()
            return opts.find_fn(opts.locator, data)
          end
        end
      end

      opts.Job:continue(ctx)
    end)

    coroutine.yield({ locator_name = opts.locator.name, wait = true })
  end)
end

local get_interpreter_path = util.get_interpreter_path
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---Shared _find for locators that scan a directory for subdirectories containing a Python interpreter.
---@param locator WhichPy.Locator
---@param dir string
---@return fun(): WhichPy.InterpreterInfo?
function M.find_interpreters_in_dir(locator, dir)
  return coroutine.wrap(function()
    if not vim.uv.fs_stat(dir) then
      return
    end
    for name, t in vim.fs.dir(dir) do
      if t == "directory" then
        local path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
        if vim.uv.fs_stat(path) then
          coroutine.yield(InterpreterInfo:new({ locator = locator, path = path }))
        end
      end
    end
  end)
end

return M
