local util = require("whichpy.util")
local is_win = vim.uv.os_uname().sysname == "Windows_NT"
local get_interpreter_path = util.get_interpreter_path

local common_posix_bin_paths = {
  "/bin",
  "/etc",
  "/lib",
  "/lib/x86_64-linux-gnu",
  "/lib64",
  "/sbin",
  "/snap/bin",
  "/usr/bin",
  "/usr/games",
  "/usr/include",
  "/usr/lib",
  "/usr/lib/x86_64-linux-gnu",
  "/usr/lib64",
  "/usr/libexec",
  "/usr/local",
  "/usr/local/bin",
  "/usr/local/etc",
  "/usr/local/games",
  "/usr/local/lib",
  "/usr/local/sbin",
  "/usr/sbin",
  "/usr/share",
  "~/.local/bin",
}

local get_pyenv_shims_dir = function()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return vim.fs.joinpath(pyenv_root, "shims")
end

local get_search_path_entries = function()
  local delimiter = (is_win and ";") or ":"
  local dirs = vim.split(vim.env.PATH or vim.env.Path, delimiter)
  if not is_win then
    dirs = vim.list_extend(dirs, common_posix_bin_paths)
  end
  local pyenv_shims = get_pyenv_shims_dir()
  return vim
    .iter(dirs)
    :filter(function(dir)
      return dir ~= pyenv_shims
    end)
    :map(function(dir)
      return vim.fn.fnamemodify(dir, ":p")
    end)
    :totable()
end

return {
  find = function()
    return coroutine.wrap(function()
      local dirs = util.deduplicate(get_search_path_entries())

      for _, dir in ipairs(dirs) do
        local interpreter_path = get_interpreter_path(dir, "root")
        if vim.uv.fs_stat(interpreter_path) then
          coroutine.yield(interpreter_path)
        end
      end
    end)
  end,
  resolve = function(interpreter_path)
    return {
      locator = "Global",
      interpreter_path = interpreter_path,
    }
  end,
}
