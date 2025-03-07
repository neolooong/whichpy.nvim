local M = {
  _augroup = {},
  _clients = {},
}

function M.create_autocmd()
  local config = require("whichpy.config").config

  M._augroup = vim.api.nvim_create_augroup("WhichPy", { clear = true })
  vim.api.nvim_create_autocmd({ "LspAttach" }, {
    pattern = { "*" },
    group = M._augroup,
    callback = function(args)
      local client_id = args["data"]["client_id"]
      local client = vim.lsp.get_client_by_id(client_id)
      if client == nil then
        return
      end
      local client_name = client["name"]

      if config.lsp[client_name] == nil then
        return
      end

      local selected = require("whichpy.envs").current_selected()
      local selected_explicitly = require("whichpy.envs").current_selected_explicitly()
      if next(M._clients) == nil and (selected == nil or
                (config.auto_select_on_current_implicit and not selected_explicitly)) then
        require("whichpy.envs").retrieve_cache()
      elseif M._clients[client_name] ~= client_id and selected ~= nil then
        config.lsp[client_name].set_python_path(client, selected)
      end
      M._clients[client_name] = client_id
    end,
  })
end

return M
