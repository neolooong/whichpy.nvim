local M = {
  _augroup = {},
  _clients = {},
  _restart_by_whichpy = {},
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

  local envs = require("whichpy.envs")
  local selected = envs.current_selected()
  local has_selected = selected ~= nil

  if next(M._clients) == nil and not has_selected then
    envs.retrieve_cache()
  end

  local client_state = M._clients[client_name]
  local is_new_client = client_state == nil
  local is_same_client = not is_new_client and client_state.client_id == client_id

  if not is_same_client and has_selected then
    if is_new_client then
      config.lsp[client_name]:snapshot_settings(client)
    end

    if
      not M._restart_by_whichpy[client.name]
      and (
        is_new_client
        or not is_same_client
        or (is_same_client and client_state.last_selected ~= selected)
      )
    then
      config.lsp[client_name]:set_python_path(client, selected)
    end

    if M._restart_by_whichpy[client.name] then
      M._restart_by_whichpy[client.name] = nil
    end
  end

  M._clients[client_name] = {
    client_id = client_id,
    last_selected = selected,
  }
end

function M.create_autocmd()
  M._augroup = vim.api.nvim_create_augroup("WhichPy", { clear = true })
  vim.api.nvim_create_autocmd({ "LspAttach" }, {
    pattern = { "*" },
    group = M._augroup,
    callback = M.lsp_attach_callback,
  })
end

function M.skip_next_set_python_path(client)
  M._restart_by_whichpy[client.name] = true
end

return M

