local config = require("whichpy.config").config
local util = require("whichpy.util")
local is_win = util.is_win
local cache = require("whichpy.cache")
local SearchJob = require("whichpy.search")
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

local state = {
  envs = {}, ---@type WhichPy.InterpreterInfo[]
  current_path = nil, ---@type string?
  current_env_name = nil, ---@type string?
  original = nil, ---@type table?
}

local M = {}

M.asearch = function()
  SearchJob:start()
end

---@param envs WhichPy.InterpreterInfo[]
M.set_envs = function(envs)
  state.envs = envs
end

---@return WhichPy.InterpreterInfo[]
M.get_envs = function()
  if SearchJob:status() == "dead" then
    return state.envs
  end
  return SearchJob._temp_envs
end

M.show_selector = function()
  require("whichpy.picker")[config.picker.name]:show()
end

---@param selected WhichPy.InterpreterInfo
---@param should_backup boolean
local function apply_to_lsp(selected, should_backup)
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      if should_backup then
        handler:snapshot_settings(client)
      end
      handler:set_python_path(client, selected.path)
    end
  end
end

---@param selected WhichPy.InterpreterInfo
---@param should_backup boolean
---@return function? orig_dap_resolve
local function apply_to_dap(selected, should_backup)
  local ok, dap_python = pcall(require, "dap-python")
  if not ok then
    return nil
  end
  local orig = nil
  if should_backup then
    orig = dap_python.resolve_python
  end
  dap_python.resolve_python = function()
    return selected.path
  end
  return orig
end

---@param selected WhichPy.InterpreterInfo
local function apply_env_vars(selected)
  local env_var = selected.env_var
  if env_var.name == "VIRTUAL_ENV" then
    vim.env.VIRTUAL_ENV = env_var.val
    vim.env.CONDA_PREFIX = nil
  elseif env_var.name == "CONDA_PREFIX" then
    vim.env.VIRTUAL_ENV = nil
    vim.env.CONDA_PREFIX = env_var.val
  else
    vim.env.VIRTUAL_ENV = nil
    vim.env.CONDA_PREFIX = nil
  end
  state.current_env_name = selected.env_var.val

  util.notify("$VIRTUAL_ENV: " .. (vim.env.VIRTUAL_ENV or "nil"))
  util.notify("$CONDA_PREFIX: " .. (vim.env.CONDA_PREFIX or "nil"))
end

---@param selected_path string
local function apply_path(selected_path)
  local delimiter = (is_win and ";") or ":"
  if state.current_path then
    vim.env.PATH = vim.env.PATH:gsub(vim.fs.dirname(state.current_path) .. delimiter, "", 1)
  end
  vim.env.PATH = vim.fs.dirname(selected_path) .. delimiter .. vim.env.PATH

  util.notify("Prepend " .. vim.fs.dirname(selected_path) .. " to $PATH.")
end

local function backup_original_state()
  state.original = {
    envvar = {
      CONDA_PREFIX = vim.env.CONDA_PREFIX,
      VIRTUAL_ENV = vim.env.VIRTUAL_ENV,
    },
    dap = nil,
  }
end

---@param selected WhichPy.InterpreterInfo
---@param should_cache? boolean
M.handle_select = function(selected, should_cache)
  local is_first = state.original == nil
  should_cache = should_cache == nil or should_cache

  if is_first then
    backup_original_state()
  end

  apply_to_lsp(selected, is_first)

  local orig_dap = apply_to_dap(selected, is_first)
  if is_first and orig_dap ~= nil then
    state.original.dap = orig_dap
  end

  apply_env_vars(selected)

  if config.update_path_env then
    apply_path(selected.path)
  end

  if should_cache then
    cache.save(config.cache_dir, selected.path, selected.locator_name)
  end

  state.current_path = selected.path

  if config.after_handle_select then
    config.after_handle_select(selected)
  end
end

local function restore_lsp()
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      handler:restore_snapshot(client)
    end
  end
end

local function restore_dap()
  local ok, dap_python = pcall(require, "dap-python")
  if ok then
    dap_python.resolve_python = state.original.dap
  end
end

local function restore_env_vars()
  vim.env.VIRTUAL_ENV = state.original.envvar.VIRTUAL_ENV
  vim.env.CONDA_PREFIX = state.original.envvar.CONDA_PREFIX

  util.notify("$VIRTUAL_ENV: " .. (vim.env.VIRTUAL_ENV or "nil"))
  util.notify("$CONDA_PREFIX: " .. (vim.env.CONDA_PREFIX or "nil"))
end

local function restore_path()
  local delimiter = (is_win and ";") or ":"
  vim.env.PATH = vim.env.PATH:gsub(vim.fs.dirname(state.current_path) .. delimiter, "", 1)
end

M.handle_reset = function()
  if state.original == nil then
    return
  end

  restore_lsp()
  restore_dap()
  restore_env_vars()

  if config.update_path_env then
    restore_path()
  end

  cache.remove(config.cache_dir)

  state.original = nil
  state.current_path = nil
  state.current_env_name = nil
end

M.retrieve_cache = function()
  local path, locator_name = cache.load(config.cache_dir)
  if not path then
    return
  end

  local locator = require("whichpy.locator").get_locator(locator_name or "global")
  if not locator then
    return
  end
  M.handle_select(
    InterpreterInfo:new({
      locator = locator,
      path = path,
    }),
    false
  )
end

---@return string?
M.current_selected = function()
  return state.current_path
end

---@return string?
M.current_selected_name = function()
  return state.current_env_name
end

return M
