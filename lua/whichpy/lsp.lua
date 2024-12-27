---@class WhichPy.Lsp.Handler
---@field get_python_path fun(client: vim.lsp.Client): string?
---@field set_python_path fun(client: vim.lsp.Client, python_path: string)

---@class WhichPy.Lsp.PylspHandler: WhichPy.Lsp.Handler

---@class WhichPy.Lsp.PyrightHandler: WhichPy.Lsp.Handler

local get_interpreter_path = require("whichpy.util").get_interpreter_path

local M = {
  _augroup = {},
  _clients = {},
}

function M.create_autocmd()
  local config = require("whichpy.config").config

  M._augroup = vim.api.nvim_create_augroup("WhichPy", { clear = true })
  vim.api.nvim_create_autocmd({ "LspAttach" }, {
    pattern = { "*" },
    group = M._augroup,
    callback = function(args)
      local client_id = args["data"]["client_id"]
      local client = vim.lsp.get_client_by_id(client_id)
      if client == nil then
        return
      end
      local client_name = client["name"]

      if config.lsp[client_name] == nil then
        return
      end

      local selected = require("whichpy.envs").current_selected()
      if next(M._clients) == nil and selected == nil then
        require("whichpy.envs").retrieve_cache()
      elseif M._clients[client_name] ~= client_id and selected ~= nil then
        config.lsp[client_name].set_python_path(client, selected)
      end
      M._clients[client_name] = client_id
    end,
  })
end

---@type table<string,WhichPy.Lsp.Handler>
M.handlers = {}

---@type WhichPy.Lsp.PylspHandler
M.handlers.pylsp = {
  get_python_path = function(client)
    if
      client.settings.pylsp
      and client.settings.pylsp.plugins
      and client.settings.pylsp.plugins.jedi
    then
      return client.settings.pylsp.plugins.jedi.environment
    end
    return nil
  end,
  set_python_path = function(client, python_path)
    if python_path then
      client.settings = vim.tbl_deep_extend("force", client.settings, {
        pylsp = {
          plugins = {
            jedi = {
              environment = python_path,
            },
          },
        },
      })
    else
      client.settings.pylsp.plugins.jedi.environment = nil
    end
    client.notify("workspace/didChangeConfiguration", { settings = client.settings })
  end,
}

---@type WhichPy.Lsp.PyrightHandler
M.handlers.pyright = {
  get_python_path = function(client)
    if client.settings.python then
      return client.settings.python.pythonPath
    end
    return nil
  end,
  set_python_path = function(client, python_path)
    if python_path then
      client.settings =
        vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = python_path } })
      client.notify("workspace/didChangeConfiguration", { settings = nil })
    else
      vim.cmd(("LspRestart %s"):format(client.id))
    end
  end,
}

---find the default python_path
---@param workspace string
---@return string
M.find_python_path = function(workspace)
  if vim.env.VIRTUAL_ENV then
    return get_interpreter_path(vim.env.VIRTUAL_ENV, "bin")
  end

  if workspace and vim.fn.filereadable(vim.fs.joinpath(workspace, "poetry.lock")) then
    local ok, res = pcall(function()
      return vim.system({ "poetry", "env", "info", "-p" }):wait()
    end)
    if ok and res.code == 0 then
      return get_interpreter_path(vim.trim(res.stdout), "bin")
    end
  end

  if workspace and vim.fn.filereadable(vim.fs.joinpath(workspace, "Pipfile")) then
    local ok, res = pcall(function()
      return vim
        .system(
          { "pipenv", "--venv" },
          { env = { PIPENV_PIPFILE = vim.fs.joinpath(workspace, "Pipfile") } }
        )
        :wait()
    end)
    if ok and res.code == 0 then
      return get_interpreter_path(vim.trim(res.stdout), "bin")
    end
  end

  local ok, res = pcall(function()
    return vim.system({ "pyenv", "which", "python" }):wait()
  end)
  if ok and res.code == 0 then
    return vim.trim(res.stdout)
  end

  return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
end

return M
