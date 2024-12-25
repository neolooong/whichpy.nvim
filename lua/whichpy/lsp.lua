---@class WhichPy.Lsp.Handler
---@field get_python_path fun(client: vim.lsp.Client): string?
---@field set_python_path fun(client: vim.lsp.Client, python_path: string)

---@class WhichPy.Lsp.PylspHandler: WhichPy.Lsp.Handler

---@class WhichPy.Lsp.PyrightHandler: WhichPy.Lsp.Handler

local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path

local M = {}

---@type table<string,WhichPy.Lsp.Handler>
M.handlers = {}

M.handlers.pylsp = {
  get_python_path = function(client)
    if vim.fn.has("nvim-0.9.0") == 1 then
      if
        client.config.settings.settings
        and client.config.settings.settings.pylsp
        and client.config.settings.pylsp.plugins
        and client.config.settings.pylsp.plugins.jedi
      then
        return client.config.settings.pylsp.plugins.jedi.environment
      end
    else
      if
        client.settings.pylsp
        and client.settings.pylsp.plugins
        and client.settings.pylsp.plugins.jedi
      then
        return client.settings.pylsp.plugins.jedi.environment
      end
    end
    return nil
  end,
  set_python_path = function(client, python_path)
    if vim.fn.has("nvim-0.9.0") == 1 then
      if python_path then
        client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
          pylsp = {
            plugins = {
              jedi = {
                environment = python_path,
              },
            },
          },
        })
      else
        client.config.settings.pylsp.plugins.jedi.environment = nil
      end
      client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    else
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
    end
  end,
}

M.handlers.pyright = {
  get_python_path = function(client)
    if vim.fn.has("nvim-0.9.0") == 1 then
      if client.config.settings.python then
        return client.config.settings.python.pythonPath
      end
    else
      if client.settings.python then
        return client.settings.python.pythonPath
      end
    end
    return nil
  end,
  set_python_path = function(client, python_path)
    if python_path then
      if vim.fn.has("nvim-0.9.0") == 1 then
        client.config.settings = vim.tbl_deep_extend(
          "force",
          client.config.settings,
          { python = { pythonPath = python_path } }
        )
        client.notify("workspace/didChangeConfiguration", { settings = nil })
      else
        client.settings =
          vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = python_path } })
        client.notify("workspace/didChangeConfiguration", { settings = nil })
      end
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

  if workspace and vim.fn.filereadable(util.joinpath(workspace, "poetry.lock")) then
    local ok, res = pcall(function()
      return vim.system({ "poetry", "env", "info", "-p" }):wait()
    end)
    if ok and res.code == 0 then
      return get_interpreter_path(vim.trim(res.stdout), "bin")
    end
  end

  if workspace and vim.fn.filereadable(util.joinpath(workspace, "Pipfile")) then
    local ok, res = pcall(function()
      return vim
        .system({ "pipenv", "--venv" }, { env = { PIPENV_PIPFILE = util.joinpath(workspace, "Pipfile") } })
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
