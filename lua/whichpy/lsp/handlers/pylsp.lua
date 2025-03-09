---@class WhichPy.Lsp.PylspHandler: WhichPy.Lsp.Handler
---@field snapshot? table
---@field server_default? table
local M = {}
M.__index = M

function M.new()
  local obj = {
    server_default = {
      jedi_environment = nil,
      mypy_overrides = { true },
    },
  }
  return setmetatable(obj, M)
end

function M:snapshot_settings(client)
  if self.snapshot ~= nil then
    return
  end
  self.snapshot = {}

  if
    client.settings.pylsp
    and client.settings.pylsp.plugins
    and client.settings.pylsp.plugins.jedi
  then
    self.snapshot.jedi_environment = client.settings.pylsp.plugins.jedi.environment
  else
    self.snapshot.jedi_environment = self.server_default.jedi_environment
  end

  if
    client.settings.pylsp
    and client.settings.pylsp.plugins
    and client.settings.pylsp.plugins.pylsp_mypy
  then
    self.snapshot.mypy_overrides = client.settings.pylsp.plugins.pylsp_mypy.overrides
  else
    self.snapshot.mypy_overrides = self.server_default.mypy_overrides
  end
end

function M:restore_snapshot(client)
  self:set_python_path(client, nil)
end

function M:set_python_path(client, python_path)
  if python_path then
    local mypy_overrides

    local option_name = "--python-executable"
    if vim.tbl_contains(self.snapshot.mypy_overrides, option_name) then
      mypy_overrides = {}
      local option_value_index = 0
      for index, value in ipairs(self.snapshot.mypy_overrides) do
        if value == option_name then
          option_value_index = index + 1
          mypy_overrides[index] = value
        elseif index == option_value_index then
          mypy_overrides[index] = python_path
        else
          mypy_overrides[index] = value
        end
      end
    else
      mypy_overrides = { "--python-executable", python_path, unpack(self.snapshot.mypy_overrides) }
    end

    client.settings = vim.tbl_deep_extend("force", client.settings, {
      pylsp = {
        plugins = {
          jedi = {
            environment = python_path,
          },
          pylsp_mypy = {
            overrides = mypy_overrides,
          },
        },
      },
    })
  else
    client.settings.pylsp.plugins.jedi.environment = self.snapshot.jedi_environment
    client.settings.pylsp.plugins.pylsp_mypy.overrides = self.snapshot.mypy_overrides
  end
  client.notify("workspace/didChangeConfiguration", { settings = client.settings })
end

return M
