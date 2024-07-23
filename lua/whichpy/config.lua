local _default_config = {
  cache_dir = vim.fn.stdpath("cache") .. "/whichpy.nvim",
  locator = {
    workspace = {
      search_pattern = ".*env.*",
      depth = 2,
    },
    global = {},
    global_virtual_environment = {
      dirs = {
        "~/envs",
        "~/.direnv",
        "~/.venvs",
        "~/.virtualenvs",
        "~/.local/share/virtualenvs",
        { "~/Envs", "Linux" },
        vim.env.WORKON_HOME,
      },
    },
    pyenv = {},
    poetry = {},
    pdm = {},
    conda = {},
  },
  lsp = {
    pylsp = {
      require("whichpy.lsp").pylsp.python_path_getter,
      require("whichpy.lsp").pylsp.python_path_setter,
    },
    pyright = {
      require("whichpy.lsp").pyright.python_path_getter,
      require("whichpy.lsp").pyright.python_path_setter,
    },
  },
}

local M = {}

M.setup_config = function(opts)
  M.config = vim.tbl_deep_extend("force", _default_config, opts or {})
  for locator, locator_opts in pairs(M.config.locator) do
    if locator_opts.enable == false then
      M.config.locator[locator] = nil
    end
  end
end

return M
