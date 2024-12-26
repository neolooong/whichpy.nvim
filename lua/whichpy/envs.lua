local config = require("whichpy.config").config
local util = require("whichpy.util")
local SearchJob = require("whichpy.search")
local final_envs = {}
local orig_interpreter_path
local curr_interpreter_path

local M = {}

M.asearch = function()
  SearchJob:start()
end

M.set_envs = function(envs)
  final_envs = envs
end

M.get_envs = function()
  if SearchJob:status() == "dead" then
    return final_envs
  end
  return SearchJob:_temp_envs()
end

M.show_selector = function()
  require("whichpy.picker")[config.picker.name]:show()
end

M.handle_select = function(interpreter_path, should_cache)
  local selected = orig_interpreter_path ~= nil
  local _orig_interpreter_path = {}
  should_cache = should_cache == nil or should_cache

  if not selected then
    _orig_interpreter_path["lsp"] = {}
    _orig_interpreter_path["dap"] = {}
    _orig_interpreter_path["envvar"] = {
      CONDA_PREFIX = vim.env.CONDA_PREFIX,
      VIRTUAL_ENV = vim.env.VIRTUAL_ENV,
    }
  end

  -- lsp
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      if not selected then
        _orig_interpreter_path["lsp"][lsp_name] = handler.get_python_path(client)
      end
      handler.set_python_path(client, interpreter_path)
    end
  end

  -- dap
  local ok, dap_python = pcall(require, "dap-python")
  if ok then
    if not selected then
      _orig_interpreter_path["dap"] = dap_python.resolve_python
    end
    dap_python.resolve_python = function()
      return interpreter_path
    end
  end

  -- envvar
  -- NOTE: Need to clear env vars to ensure DAP uses the selected interpreter environment
  -- Setting specific env vars would be possible if knowing which locator was selected.
  vim.env.VIRTUAL_ENV = nil
  vim.env.CONDA_PREFIX = nil

  -- cache
  if should_cache then
    vim.fn.mkdir(config.cache_dir, "p")
    local filename = vim.fn.getcwd():gsub("[\\/:]+", "%%")
    local f = assert(io.open(vim.fs.joinpath(config.cache_dir, filename), "wb"))
    f:write(interpreter_path)
    f:close()
  end

  if not selected then
    orig_interpreter_path = _orig_interpreter_path
  end
  curr_interpreter_path = interpreter_path
end

M.handle_restore = function()
  if orig_interpreter_path == nil then
    return
  end

  -- lsp
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      handler.set_python_path(client, orig_interpreter_path.lsp[client])
    end
  end

  -- dap
  local ok, dap_python = pcall(require, "dap-python")
  if ok then
    dap_python.resolve_python = orig_interpreter_path.dap
  end

  -- envvar
  vim.env.VIRTUAL_ENV = orig_interpreter_path.envvar.VIRTUAL_ENV
  vim.env.CONDA_PREFIX = orig_interpreter_path.envvar.CONDA_PREFIX

  -- cache
  local filename = vim.fn.getcwd():gsub("/", "%%")
  os.remove(vim.fs.joinpath(config.cache_dir, filename))

  orig_interpreter_path = nil
  curr_interpreter_path = nil
end

M.retrieve_cache = function()
  local filename = vim.fn.getcwd():gsub("/", "%%")
  local f = io.open(vim.fs.joinpath(config.cache_dir, filename), "r")
  if not f then
    util.notify("No cache.")
    return
  end
  local interpreter_path = f:read()
  f:close()

  M.handle_select(interpreter_path, false)
end

M.current_selected = function()
  return curr_interpreter_path
end

return M
