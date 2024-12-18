---@class (exact) WhichPy.Config
---@field cache_dir? string
---@field locator? WhichPy.Config.Locator
---@field lsp? table<string,WhichPy.Lsp.Handler>
---@field picker? "builtin" | "fzf-lua" | "telescope"

---@class (exact) WhichPy.Config.Locator
---@field workspace? WhichPy.Config.Locator.Workspace
---@field global? WhichPy.Config.Locator.Global
---@field global_virtual_environment? WhichPy.Config.Locator.GlobalVirtualEnvironment
---@field pyenv? WhichPy.Config.Locator.Pyenv
---@field poetry? WhichPy.Config.Locator.Poetry
---@field pdm? WhichPy.Config.Locator.Pdm
---@field conda? WhichPy.Config.Locator.Conda

---@class (exact) WhichPy.Config.Locator.Workspace
---@field search_pattern? string
---@field depth? integer
---@field ignore_dirs? string[]

---@class (exact) WhichPy.Config.Locator.Global

---@class (exact) WhichPy.Config.Locator.GlobalVirtualEnvironment
---@field dirs? (string|{[1]: string, [2]: string})[]

---@class (exact) WhichPy.Config.Locator.Pyenv

---@class (exact) WhichPy.Config.Locator.Poetry

---@class (exact) WhichPy.Config.Locator.Pdm

---@class (exact) WhichPy.Config.Locator.Conda

---@type WhichPy.Config
local _default_config = {
  cache_dir = vim.fn.stdpath("cache") .. "/whichpy.nvim",
  picker = "builtin",
  locator = {
    workspace = {
      search_pattern = ".*env.*",
      depth = 2,
      ignore_dirs = {
        ".git",
        ".mypy_cache",
        ".pytest_cache",
        ".ruff_cache",
        "__pycache__",
        "__pypackages__",
      },
    },
    global = {},
    global_virtual_environment = {
      dirs = {
        "~/envs",
        "~/.direnv",
        "~/.venvs",
        "~/.virtualenvs",
        "~/.local/share/virtualenvs",
        { "~/Envs", "Windows_NT" },
        vim.env.WORKON_HOME,
      },
    },
    pyenv = {},
    poetry = {},
    pdm = {},
    conda = {},
  },
  lsp = {
    pylsp = require("whichpy.lsp").handlers.pylsp,
    pyright = require("whichpy.lsp").handlers.pyright,
    basedpyright = require("whichpy.lsp").handlers.pyright,
  },
}

local M = {}

M.setup_config = function(opts)
  M.config = vim.tbl_deep_extend("force", _default_config, opts or {})

  for locator_name, locator_opts in pairs(M.config.locator) do
    require("whichpy.locator").setup_locator(locator_name, locator_opts)
  end
end

return M
