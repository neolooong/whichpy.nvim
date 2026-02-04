---@class WhichPy.Lsp.TyHandler: WhichPy.Lsp.Handler
---@field snapshot? table
---@field server_default? table
local M = {}
M.__index = M

function M.new()
  return setmetatable({}, M)
end

function M:snapshot_settings(_)
  --
end

function M:restore_snapshot(client)
  self:set_python_path(client, nil)
end

function M:set_python_path(client, _)
  vim.defer_fn(function ()
    require("whichpy.lsp").skip_next_set_python_path(client)
    vim.cmd(("LspRestart %s"):format(client.name))
  end, 200)
end

return M
