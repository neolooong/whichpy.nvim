# whichpy.nvim

Yet another python interpreter selector plugin for neovim. Make LSPs (pyright, pylsp, basedpyright) and DAP work with specific python.


https://github.com/user-attachments/assets/bddd568a-947a-49d2-a403-efae2787f60a


## Features

- Support multiple Lsp servers. (Pylsp, Pyright, BasedPyright)
- Support nvim-dap-python.
- Switch between python interpreters without restart LSPs. (Except `WhichPy restore` on Pyright)
- Support multiple pickers. (`builtin`, `fzf-lua`, `telescope`)
- Automatically select the previously chosen interpreter based on the directory.
- Search on common directories, currently support:
  - workspace (relative path of `vim.fn.getcwd()`)
  - global (`vim.env.Path` and common posix paths)
  - global virtual environment
  - pyenv
  - poetry
  - pdm
  - conda

## Requirements

- Neovim >= 0.10.0

## Installation

- Using lazy.nvim:

```lua
{
  "neolooong/whichpy.nvim",
  dependencies = {
    -- optional for dap
    -- "mfussenegger/nvim-dap-python",
    -- optional for picker support
    -- "ibhagwan/fzf-lua",
    -- "nvim-telescope/telescope.nvim",
  }
  opts = {},
}
```

## Configuration

<details>
  <summary>whichpy.nvim comes with these defaults:</summary>

  ```lua
  {
    cache_dir = vim.fn.stdpath("cache") .. "/whichpy.nvim",
    picker = {
      name = "builtin",  -- must be one of ("builtin", "fzf-lua", "telescope")
      -- You can customize the picker as follows. For available options, refer to the respective documentation.
      -- ["fzf-lua"] = {
      --   prompt="fzf-lua",
      -- },
      -- telescope = {
      --   prompt_title="telescope",
      -- },
      -- builtin = {
      --   prompt="vim.ui.select",
      -- },
    },
    locator = {
      -- you can disable locator like this
      -- locator_name = { enable = false },
      workspace = {
        search_pattern = ".*env.*", -- `:help lua-patterns`
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
          -- accept following structure
          -- path
          -- { path, vim.uv.os_uname().sysname }
          "~/envs",
          "~/.direnv",
          "~/.venvs",
          "~/.virtualenvs",
          "~/.local/share/virtualenvs",
          { "~/Envs", "Windows_NT" },  -- only search on Windows
          vim.env.WORKON_HOME,
        }
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
  ```
</details>

## Commands

This plugin provide these commands:

### `:WhichPy select [path?]`

  If `path` provided, LSPs would be configured. Otherwise, picker would show up.

### `:WhichPy restore`

  Restore LSPs configuration, and clear the cache.

### `:WhichPy retrieve`

  Retrieve the interpreter path from cache, then configure lsp.

### `:WhichPy rescan`

  Search python interpreter again.

## FAQ

<details>
  <summary>How to work with neotest?</summary>

  ```lua
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-neotest/neotest-python",
    },
    config = function()
      local python_adapter = require("neotest-python")({
        python = function()
          local whichpy_python = require("whichpy.envs").current_selected()
          if whichpy_python then
            return whichpy_python
          end
          return require("neotest-python.base").get_python_command
        end,
      })
      require("neotest").setup({
        adapters = { python_adapter },
      })
    end,
  }
  ```
</details>

<details>
  <summary>Why don't use `fd`?</summary>

  1. I'm not familiar with `fd`. (main reason)
  2. I only want to search a specific directory. `vim.uv.fs_stat` is fast enough for me.

  Once I'm become more familiar with `fd` and have free time. I'll try.
</details>

## Acknowledgments

- [venv-selector.nvim](https://github.com/linux-cultist/venv-selector.nvim) for inspiring the Python path setup.
- [vscode-python](https://github.com/microsoft/vscode-python) for numerous locator implementation.
- [async.nvim](https://github.com/lewis6991/async.nvim) for the async implementation.
- and many publicly shared dotfiles on Github.
