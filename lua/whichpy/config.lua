---@class (exact) WhichPy.Config
---@field cache_dir? string
---@field locator? WhichPy.Config.Locator
---@field lsp? table<string,WhichPy.Lsp.Handler>
---@field picker? WhichPy.Config.Picker
---@field update_path_env? boolean
---@field auto_select_when_current_implicit? boolean
---@field after_handle_select? fun(selected: WhichPy.InterpreterInfo)

---@class (exact) WhichPy.Config.Locator
---@field workspace? WhichPy.Config.Locator.Workspace
---@field global? WhichPy.Config.Locator.Global
---@field global_virtual_environment? WhichPy.Config.Locator.GlobalVirtualEnvironment
---@field pyenv? WhichPy.Config.Locator.Pyenv
---@field poetry? WhichPy.Config.Locator.Poetry
---@field pdm? WhichPy.Config.Locator.Pdm
---@field conda? WhichPy.Config.Locator.Conda
---@field uv? WhichPy.Config.Locator.Uv

---@alias WhichPy.Config.Locator.Workspace WhichPy.Locator.Opts|WhichPy.Locator.Workspace.Opts
---@alias WhichPy.Config.Locator.Global WhichPy.Locator.Opts|WhichPy.Locator.Global.Opts
---@alias WhichPy.Config.Locator.GlobalVirtualEnvironment WhichPy.Locator.Opts|WhichPy.Locator.GlobalVirtualEnvironment.Opts
---@alias WhichPy.Config.Locator.Pyenv WhichPy.Locator.Opts|WhichPy.Locator.Pyenv.Opts
---@alias WhichPy.Config.Locator.Poetry WhichPy.Locator.Opts|WhichPy.Locator.Poetry.Opts
---@alias WhichPy.Config.Locator.Pdm WhichPy.Locator.Opts|WhichPy.Locator.Pdm.Opts
---@alias WhichPy.Config.Locator.Conda WhichPy.Locator.Opts|WhichPy.Locator.Conda.Opts
---@alias WhichPy.Config.Locator.Uv WhichPy.Locator.Opts|WhichPy.Locator.Uv.Opts

---@class WhichPy.Config.Picker
---@field name? "builtin"|"fzf-lua"|"telescope"
---@field builtin? table
---@field fzf-lua? table
---@field telescope? table

---@type WhichPy.Config
local _default_config = {
  cache_dir = vim.fn.stdpath("cache") .. "/whichpy.nvim",
  picker = { name = "builtin" },
  update_path_env = false,
  locator = {
    workspace = {},
    global = {},
    global_virtual_environment = {},
    pyenv = {},
    poetry = {},
    pdm = {},
    conda = {},
  },
  lsp = {
    pylsp = require("whichpy.lsp.handlers.pylsp"),
    pyright = require("whichpy.lsp.handlers.pyright"),
    basedpyright = require("whichpy.lsp.handlers.pyright"),
  },
  after_handle_select = nil,
}

local M = {}

M.setup_config = function(opts)
  M.config = vim.tbl_deep_extend("force", _default_config, opts or {})

  for locator_name, locator_opts in pairs(M.config.locator) do
    require("whichpy.locator").setup_locator(locator_name, locator_opts)
  end
end

return M
