local config = require("whichpy.config").config
local _envs = {}
local orig_envvar
local curr_env_info
local searching_status = "NOT_STARTED"

local M = {}

---@param notify_on_complete boolean
M.search = function(notify_on_complete)
  notify_on_complete = notify_on_complete or false

  if searching_status == "NOT_STARTED" or searching_status == "DONE" then
    searching_status = "IN_PROGRESS"
    vim.schedule(function()
      local envs = {}
      for locator_name, _ in pairs(config.locator) do
        local locator = require("whichpy.locator")[locator_name]
        if locator ~= nil then
          for interpreter_path in locator.find() do
            local env_info = locator.resolve(interpreter_path)
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
          end
        end
      end

      _envs = envs
      searching_status = "DONE"
      if notify_on_complete then
        require("whichpy.util").notify_info("Search completed.")
      end
    end)
  end
end

M.get_envs = function()
  if searching_status == "DONE" then
    return _envs
  end
  return {}
end

M.show_selector = function()
  if searching_status ~= "DONE" then
    local timer = assert(vim.uv.new_timer())
    timer:start(100, 100, function()
      if searching_status == "DONE" then
        timer:close()
        vim.schedule_wrap(function()
          vim.ui.select(_envs, { prompt = "Select Python Interpreter" }, function(choice)
            if choice ~= nil then
              M.handle_select(choice)
            end
          end)
        end)()
      end
    end)
    return
  end
  vim.ui.select(_envs, { prompt = "Select Python Interpreter" }, function(choice)
    if choice ~= nil then
      M.handle_select(choice)
    end
  end)
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

  -- dap
  pcall(function()
    require("dap-python").resolve_python = function()
      return env_info.interpreter_path
    end
  end)

  -- lsp
  for lsp_name, obj in pairs(config.lsp) do
    local pp_getter, pp_setter = unpack(obj)
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      if not selected then
        _orig_envvar["lsp"][lsp_name] = pp_getter(client)
      end
      pp_setter(client, env_info.interpreter_path)
    end
  end

  -- cache
  if should_cache then
    vim.fn.mkdir(config.cache_dir, "p")
    local filename = vim.fn.getcwd():gsub("/", "%%")
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

  -- dap
  pcall(function()
    require("dap-python").resolve_python = nil
  end)

  -- lsp
  for lsp_name, obj in pairs(config.lsp) do
    local _, pp_setter = unpack(obj)
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      pp_setter(client, orig_envvar.lsp[client])
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
