local M = {
  _augroup = {},
  _clients = {},
}

function M.lsp_attach_callback(args)
  local client_id = args["data"]["client_id"]
  local client = vim.lsp.get_client_by_id(client_id)
  if client == nil then
    return
  end
  local client_name = client["name"]

  local config = require("whichpy.config").config
  if config.lsp[client_name] == nil then
    return
  end

  local selected = require("whichpy.envs").current_selected()
  if next(M._clients) == nil and selected == nil then
    require("whichpy.envs").retrieve_cache()
  elseif M._clients[client_name] ~= client_id and selected ~= nil then
    if M._clients[client_name] == nil then
      config.lsp[client_name]:snapshot_settings(client)
    end
    config.lsp[client_name]:set_python_path(client, selected)
  end
  M._clients[client_name] = client_id
end

function M.create_autocmd()
  M._augroup = vim.api.nvim_create_augroup("WhichPy", { clear = true })
  vim.api.nvim_create_autocmd({ "LspAttach" }, {
    pattern = { "*" },
    group = M._augroup,
    callback = M.lsp_attach_callback,
  })
end

return M
