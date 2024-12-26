local is_win = (vim.uv or vim.loop).os_uname().sysname == "Windows_NT"
local get_interpreter_path = require("whichpy.util").get_interpreter_path
local asystem = require("whichpy.async").asystem

local get_conda_info = function()
  local ok, res = asystem({ "conda", "info", "--json" }, {})

  if ok and res.code == 0 then
    return res.stdout
  end
end

local get_conda_envs = function(info)
  return vim.json.decode(info).envs
end

return {
  find = function()
    local conda_info = get_conda_info()

    return coroutine.wrap(function()
      if not conda_info then
        return
      end
      local envs = get_conda_envs(conda_info)

      for _, env in ipairs(envs) do
        local interpreter_path = get_interpreter_path(env, is_win and "root" or "bin")
        if (vim.uv or vim.loop).fs_stat(interpreter_path) then
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
