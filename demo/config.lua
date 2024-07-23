for name, url in pairs({
  ["nvim-lspconfig"] = "https://github.com/neovim/nvim-lspconfig.git",
  ["whichpy.nvim"] = "https://github.com/neolooong/whichpy.nvim.git",
}) do
  local install_path = vim.fn.fnamemodify("plugins/" .. name, ":p")
  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({ "git", "clone", "--depth=1", url, install_path })
  end
  vim.opt.runtimepath:append(install_path)
end

local lspconfig = require("lspconfig")
lspconfig.pyright.setup({})

local whichpy = require("whichpy")
whichpy.setup({})
