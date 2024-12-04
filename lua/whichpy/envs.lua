local async = require("whichpy.async")
local config = require("whichpy.config").config
local locator = require("whichpy.locator")
local _envs = {}
local orig_envvar
local curr_env_info
local search_co
local _show_on_complete = false

local M = {}

---@param notify_on_complete boolean
M.asearch = function(notify_on_complete)
  if search_co ~= nil and coroutine.status(search_co) ~= "dead" then
    return
  end
  async.run(function()
    search_co = coroutine.running()

    local envs = {}
    locator.iterate(function(env_info)
      setmetatable(env_info, {
        __tostring = function(info)
          return string.format(
            "(%s) %s",
            info.locator,
            vim.fn.fnamemodify(info.interpreter_path, ":p:~:.")
          )
        end,
      })
      table.insert(envs, env_info)
    end)

    _envs = envs
  end, function()
    if notify_on_complete then
      vim.schedule(function()
        require("whichpy.util").notify_info("Search completed.")
      end)
    end
    if _show_on_complete then
      _show_on_complete = false
      vim.ui.select(_envs, { prompt = "Select Python Interpreter" }, function(choice)
        if choice ~= nil then
          M.handle_select(choice)
        end
      end)
    end
  end)
end

M.get_envs = function()
  if coroutine.status(search_co) == "dead" then
    return _envs
  end
  return {}
end

M.show_selector = function()
  if search_co == nil then
    _show_on_complete = true
    M.asearch(false)
  elseif coroutine.status(search_co) ~= "dead" then
    _show_on_complete = true
  else
    vim.ui.select(_envs, { prompt = "Select Python Interpreter" }, function(choice)
      if choice ~= nil then
        M.handle_select(choice)
      end
    end)
  end
end

M.handle_select = function(env_info, should_cache)
  local selected = orig_envvar ~= nil
  local _orig_envvar = {}
  should_cache = should_cache == nil or should_cache

  if not selected then
    _orig_envvar["lsp"] = {}
    _orig_envvar["VIRTUAL_ENV"] = vim.env.VIRTUAL_ENV
    _orig_envvar["CONDA_PREFIX"] = vim.env.CONDA_PREFIX
  end

  -- $VIRTUAL_ENV, $CONDA_PREFIX
  vim.env.VIRTUAL_ENV = nil
  vim.env.CONDA_PREFIX = nil

  -- lsp
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      if not selected then
        _orig_envvar["lsp"][lsp_name] = handler.get_python_path(client)
      end
      handler.set_python_path(client, env_info.interpreter_path)
    end
  end

  -- cache
  if should_cache then
    vim.fn.mkdir(config.cache_dir, "p")
    local filename = vim.fn.getcwd():gsub("[\\/:]+", "%%")
    local f = assert(io.open(vim.fs.joinpath(config.cache_dir, filename), "wb"))
    f:write(env_info.interpreter_path)
    f:close()
  end

  if not selected then
    orig_envvar = _orig_envvar
  end
  curr_env_info = env_info
end

M.handle_restore = function()
  if orig_envvar == nil then
    return
  end

  -- $VIRTUAL_ENV, $CONDA_PREFIX
  vim.env.VIRTUAL_ENV = orig_envvar.VIRTUAL_ENV
  vim.env.CONDA_PREFIX = orig_envvar.CONDA_PREFIX

  -- lsp
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      handler.set_python_path(client, orig_envvar.lsp[client])
    end
  end

  -- cache
  local filename = vim.fn.getcwd():gsub("/", "%%")
  os.remove(vim.fs.joinpath(config.cache_dir, filename))

  orig_envvar = nil
  curr_env_info = nil
end

M.retrieve_cache = function()
  local filename = vim.fn.getcwd():gsub("/", "%%")
  local f = io.open(vim.fs.joinpath(config.cache_dir, filename), "r")
  if not f then
    require("whichpy.util").notify_info("No cache.")
    return
  end
  local interpreter_path = f:read()
  f:close()

  M.handle_select({ interpreter_path = interpreter_path }, false)
end

M.current_selected = function()
  return curr_env_info
end

return M
