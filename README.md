# whichpy.nvim

Yet another python interpreter selector plugin for neovim. Make LSPs (pyright, pylsp, basedpyright) work with specific python.


https://github.com/user-attachments/assets/bddd568a-947a-49d2-a403-efae2787f60a



## Features

- Only `nvim-lspconfig` required.
- Use `vim.ui.select`. Enable dressing.nvim to get powerful UI.
- Support Pylsp, Pyright, BasedPyright LSP servers by default. Other LSP server can be supported with simple config.
- Switch between python interpreters without restart LSPs. (Except `WhichPy restore` on Pyright)
- Search on common directories, currently support:
  - workspace (relative path of `vim.fn.getcwd()`)
  - global (`vim.env.Path` and common posix paths)
  - global virtual environment
  - pyenv
  - poetry
  - pdm
  - conda

## Installation

- Using lazy.nvim:

```lua
return {
  "neolooong/whichpy.nvim",
  opts = {},
}
```

## Configuration

<details>
  <summary>whichpy.nvim comes with these defaults:</summary>

  ```lua
  {
    cache_dir = vim.fn.stdpath("cache") .. "/whichpy.nvim",
    locator = {
      -- you can disable locator like this
      -- locator = { enable = false },
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

- `:WhichPy select [path?]`

  If `path` provided, LSPs would be configured. Otherwise, selector prompt (through `vim.ui.select`) would show up.

- `:WhichPy restore`

  Restore LSPs configuration, and clear the cache.

- `:WhichPy retrieve`

  Retrieve the interpreter path from cache, then configure lsp.

- `:WhichPy rescan`

  Search python interpreter again. 

## Common questions

<details>
  <summary>How this plugin activate environment?</summary>

  This plugin **DOES NOT *activate*** environment (`source env/bin/activate` or `conda activate`). The purpose of the plugin is to make LSPs work with the specified python.
  
  When path selected, this plugin do these things:
  
  1. Save the environment variables: `VIRTUAL_ENV` and `CONDA_PREFIX`.
  2. Unset `VIRTUAL_ENV` and `CONDA_PREFIX`.
  3. Iterate lsp clients, save the python path that current used (if any), before update the configuration.
  
</details>

<details>
  <summary>How to activate environment automatically?</summary>

  - Activate environment before open neovim.
  - Set the python path when lsp initalize.
  
    ```lua
    -- pyright
    require("lspconfig").pyright.setup({
      on_init = function(client)
        -- 
        client.settings.python.pythonPath = require("whichpy.lsp").find_python_path(client.config.root_dir)
      end
    })
    
    -- pylsp
    require("lspconfig").pylsp.setup({
      on_init = function(client)
        client.settings = vim.tbl_deep_extend("force", client.settings, {
          pylsp = {
            plugins = {
              jedi = {
                environment = require("whichpy.lsp").find_python_path(client.config.root_dir)
              }
            }
          }
        })
      end
    })
    ```
</details>
