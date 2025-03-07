-- FIXME: may cause bug if pyright and basedpyright enable at the same time

local is_pyright_python_check = false
local pyright_python_default = nil
local pyright_python_origin = nil

---@type WhichPy.Lsp.PyrightHandler
local M = {
  get_python_path = function(client)
    if client.settings.python then
      return client.settings.python.pythonPath
    end
    return nil
  end,
  set_python_path = function(client, python_path)
    if not is_pyright_python_check then
      is_pyright_python_check = true
      if client.settings.python then
        pyright_python_origin = client.settings.python.pythonPath
      else
        pyright_python_origin = pyright_python_default
      end
    end

    python_path = python_path or pyright_python_origin

    if python_path then
      client.settings =
        vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = python_path } })
      client.notify("workspace/didChangeConfiguration", { settings = nil })
    else
      vim.cmd(("LspRestart %s"):format(client.id))
    end
  end,
}

return M
