local is_win = vim.uv.os_uname().sysname == "Windows_NT"
local bin_scripts = (is_win and "Scripts") or "bin"
local filename = (is_win and "python.exe") or "python"

local get_pyenv_version_dir = function()
  local pyenv_root = is_win and os.getenv("PYENV_ROOT") or os.getenv("PYENV")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and vim.fs.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or vim.fs.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return vim.fs.joinpath(pyenv_root, "versions")
end

return {
  find = function()
    return coroutine.wrap(function()
      local dir = get_pyenv_version_dir()

      for name, t in vim.fs.dir(dir) do
        if t == "directory" then
          local interpreter_path = vim.fs.joinpath(dir, name, bin_scripts, filename)
          if vim.uv.fs_stat(interpreter_path) then
            coroutine.yield(interpreter_path)

            local envs_dir = vim.fs.joinpath(dir, name, "envs")

            ---@diagnostic disable-next-line: redefined-local
            for name, t in vim.fs.dir(envs_dir) do
              if t == "directory" then
                interpreter_path = vim.fs.joinpath(envs_dir, name, bin_scripts, filename)
                if vim.uv.fs_stat(interpreter_path) then
                  coroutine.yield(interpreter_path)
                end
              end
            end
          end
        end
      end
    end)
  end,
  resolve = function(interpreter_path)
    return {
      locator = "Pyenv",
      interpreter_path = interpreter_path,
    }
  end,
}