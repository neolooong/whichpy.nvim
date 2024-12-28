---@type WhichPy.Lsp.PylspHandler
local M = {
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

return M
