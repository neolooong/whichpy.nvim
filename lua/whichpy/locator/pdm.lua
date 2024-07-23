local is_win = vim.uv.os_uname().sysname == "Windows_NT"
local bin_scripts = (is_win and "Scripts") or "bin"
local filename = (is_win and "python.exe") or "python"

local get_pdm_venv_location = function()
  local ok, res = pcall(function()
    return vim.system({ "pdm", "config", "venv.location" }):wait()
  end)
  if ok and res.code == 0 then
    return vim.trim(res.stdout)
  end
end

return {
  find = function()
    return coroutine.wrap(function()
      local dir = get_pdm_venv_location()
      if not dir then
        return
      end

      for name, t in vim.fs.dir(dir) do
        if t == "directory" then
          local interpreter_path = vim.fs.joinpath(dir, name, bin_scripts, filename)
          if vim.uv.fs_stat(interpreter_path) then
            coroutine.yield(interpreter_path)
          end
        end
      end
    end)
  end,
  resolve = function(interpreter_path)
    return {
      locator = "PDM",
      interpreter_path = interpreter_path,
    }
  end,
}