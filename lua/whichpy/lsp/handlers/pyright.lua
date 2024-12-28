---@type WhichPy.Lsp.PyrightHandler
local M = {
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

return M
