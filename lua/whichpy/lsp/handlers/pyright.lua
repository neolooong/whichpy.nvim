---@class WhichPy.Lsp.PyrightHandler: WhichPy.Lsp.Handler
---@field snapshot? table
---@field server_default? table
local M = {}
M.__index = M

function M.new()
  local obj = {
    server_default = {
      python_path = nil,
    },
  }
  return setmetatable(obj, M)
end

function M:snapshot_settings(client)
  if self.snapshot ~= nil then
    return
  end
  self.snapshot = {}

  if client.settings.python then
    self.snapshot.python_path = client.settings.python.pythonPath
  else
    self.snapshot.python_path = self.server_default.python_path
  end
end

function M:restore_snapshot(client)
  self:set_python_path(client, nil)
end

function M:set_python_path(client, python_path)
  python_path = python_path or self.snapshot.python_path

  if python_path then
    client.settings =
      vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = python_path } })
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  else
    vim.cmd(("LspRestart %s"):format(client.name))
  end
end

return M
