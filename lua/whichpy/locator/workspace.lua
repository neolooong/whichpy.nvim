local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path

local _opts = {}

return {
  merge_opts = function(opts)
    _opts = vim.tbl_deep_extend("force", _opts, opts or {})
  end,
  find = function()
    return coroutine.wrap(function()
      local dirs = { { vim.fn.getcwd(), 1 } }
      while #dirs > 0 do
        local dir, depth = unpack(table.remove(dirs, 1))
        local fs = (vim.uv or vim.loop).fs_scandir(dir)
        while fs do
          local name, t = (vim.uv or vim.loop).fs_scandir_next(fs)
          if not name then
            break
          end
          if t == "directory" then
            local interpreter_path = get_interpreter_path(util.joinpath(dir, name), "bin")

            if not util.list_contains(_opts.ignore_dirs, name) then
              if name:match(_opts.search_pattern) and (vim.uv or vim.loop).fs_stat(interpreter_path) then
                coroutine.yield(interpreter_path)
              elseif depth < _opts.depth then
                dirs[#dirs + 1] = { util.joinpath(dir, name), depth + 1 }
              end
            end
          end
        end
      end
    end)
  end,
  resolve = function(interpreter_path)
    return {
      locator = "Workspace",
      interpreter_path = interpreter_path,
    }
  end,
}
