local is_win = vim.uv.os_uname().sysname == "Windows_NT"
local bin_scripts = (is_win and "Scripts") or "bin"
local filename = (is_win and "python.exe") or "python"

local get_conda_info = function()
  local ok, res = pcall(function()
    return vim.system({ "conda", "info", "--json" }):wait()
  end)
  if ok and res.code == 0 then
    return vim.json.decode(res.stdout)
  end
end

local get_conda_envs = function(info)
  return vim.json.decode(info).envs
end

return {
  find = function()
    return coroutine.wrap(function()
      local conda_info = get_conda_info()
      if not conda_info then
        return
      end
      local envs = get_conda_envs(conda_info)

      for _, env in ipairs(envs) do
        local interpreter_path
        if is_win then
          interpreter_path = vim.fs.joinpath(env, filename)
        else
          interpreter_path = vim.fs.joinpath(env, bin_scripts, filename)
        end
        if vim.uv.fs_stat(interpreter_path) then
          coroutine.yield(interpreter_path)
        end
      end
    end)
  end,
  resolve = function(interpreter_path)
    return {
      locator = "Conda",
      interpreter_path = interpreter_path,
    }
  end,
}
