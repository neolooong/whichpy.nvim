local is_pylsp_jedi_environment_check = false
local pylsp_jedi_environment_default = nil
local pylsp_jedi_environment_origin = nil
local is_pylsp_mypy_overrides_check = false
local pylsp_mypy_overrides_default = { true }
local pylsp_mypy_overrides_origin = nil

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
    if not is_pylsp_jedi_environment_check then
      is_pylsp_jedi_environment_check = true
      if
        client.settings.pylsp
        and client.settings.pylsp.plugins
        and client.settings.pylsp.plugins.jedi
      then
        pylsp_jedi_environment_origin = client.settings.pylsp.plugins.jedi.environment
      else
        pylsp_jedi_environment_origin = pylsp_jedi_environment_default
      end
    end

    if not is_pylsp_mypy_overrides_check then
      is_pylsp_mypy_overrides_check = true
      if client.settings.pylsp.plugins and client.settings.pylsp.plugins.pylsp_mypy then
        pylsp_mypy_overrides_origin = client.settings.pylsp.plugins.pylsp_mypy.overrides
          or pylsp_mypy_overrides_default
      else
        pylsp_mypy_overrides_origin = pylsp_mypy_overrides_default
      end
    end

    if python_path then
      local pylsp_mypy_overrides

      local option_name = "--python-executable"
      ---@diagnostic disable-next-line: param-type-mismatch
      if vim.tbl_contains(pylsp_mypy_overrides_origin, option_name) then
        pylsp_mypy_overrides = {}
        local option_value_index = 0
        ---@diagnostic disable-next-line: param-type-mismatch
        for index, value in ipairs(pylsp_mypy_overrides_origin) do
          if value == option_name then
            option_value_index = index + 1
            pylsp_mypy_overrides[index] = value
          elseif index == option_value_index then
            pylsp_mypy_overrides[index] = python_path
          else
            pylsp_mypy_overrides[index] = value
          end
        end
      else
        pylsp_mypy_overrides =
          { "--python-executable", python_path, unpack(pylsp_mypy_overrides_default) }
      end

      client.settings = vim.tbl_deep_extend("force", client.settings, {
        pylsp = {
          plugins = {
            jedi = {
              environment = python_path,
            },
            pylsp_mypy = {
              overrides = pylsp_mypy_overrides,
            },
          },
        },
      })
    else
      client.settings.pylsp.plugins.jedi.environment = pylsp_jedi_environment_origin
      client.settings.pylsp.plugins.pylsp_mypy.overrides = pylsp_mypy_overrides_origin
        or pylsp_mypy_overrides_default
    end
    client.notify("workspace/didChangeConfiguration", { settings = client.settings })
  end,
}

return M
