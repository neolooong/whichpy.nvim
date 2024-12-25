local is_win = (vim.uv or vim.loop).os_uname().sysname == "Windows_NT"
local util = require("whichpy.util")
local get_interpreter_path = util.get_interpreter_path

local get_pyenv_version_dir = function()
  local pyenv_root = is_win and os.getenv("PYENV") or os.getenv("PYENV_ROOT")
  if pyenv_root == nil or pyenv_root == "" then
    pyenv_root = is_win and util.joinpath(os.getenv("USERPROFILE"), ".pyenv", "pyenv-win")
      or util.joinpath(os.getenv("HOME"), ".pyenv")
  end

  return util.joinpath(pyenv_root, "versions")
end

return {
  find = function()
    return coroutine.wrap(function()
      local dir = get_pyenv_version_dir()

      for name, t in vim.fs.dir(dir) do
        if t == "directory" then
          local interpreter_path = get_interpreter_path(util.joinpath(dir, name), "bin")
          if (vim.uv or vim.loop).fs_stat(interpreter_path) then
            coroutine.yield(interpreter_path)

            local envs_dir = util.joinpath(dir, name, "envs")

            ---@diagnostic disable-next-line: redefined-local
            for name, t in vim.fs.dir(envs_dir) do
              if t == "directory" then
                interpreter_path = get_interpreter_path(util.joinpath(envs_dir, name), "bin")
                if (vim.uv or vim.loop).fs_stat(interpreter_path) then
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
