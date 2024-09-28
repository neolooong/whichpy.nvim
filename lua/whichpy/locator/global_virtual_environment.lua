local get_interpreter_path = require("whichpy.util").get_interpreter_path

local _opts = {}

local get_global_virtual_environment_dirs = function()
  local sysname = vim.uv.os_uname().sysname
  local dirs = {}
  for _, value in ipairs(_opts.dirs) do
    if type(value) == "string" then
      dirs[#dirs + 1] = vim.fn.fnamemodify(value, ":p")
    else
      local dir, dir_sysname = unpack(value)
      if dir_sysname == "ALL" or dir_sysname == sysname then
        dirs[#dirs + 1] = vim.fn.fnamemodify(dir, ":p")
      end
    end
  end
  return dirs
end

return {
  merge_opts = function(opts)
    _opts = vim.tbl_deep_extend("force", _opts, opts or {})
  end,
  find = function()
    return coroutine.wrap(function()
      local dirs = get_global_virtual_environment_dirs()

      while #dirs > 0 do
        local dir = table.remove(dirs, 1)
        local fs = vim.uv.fs_scandir(dir)
        while fs do
          local name, t = vim.uv.fs_scandir_next(fs)
          if not name then
            break
          end
          if t == "directory" then
            local interpreter_path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
            if vim.uv.fs_stat(interpreter_path) then
              coroutine.yield(interpreter_path)
            end
          end
        end
      end
    end)
  end,
  resolve = function(interpreter_path)
    return {
      locator = "Global Virtual Environemnt",
      interpreter_path = interpreter_path,
    }
  end,
}
