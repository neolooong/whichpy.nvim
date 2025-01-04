local get_interpreter_path = require("whichpy.util").get_interpreter_path
local asystem = require("whichpy.async").asystem

local get_pdm_venv_location = function()
  local ok, res = asystem({ "pdm", "config", "venv.location" }, {})
  if ok and res.code == 0 then
    return vim.trim(res.stdout)
  end
end

local Locator = { name = "pdm", display_name = "PDM" }

function Locator:find()
  local dir = get_pdm_venv_location()

  return coroutine.wrap(function()
    if not dir then
      return
    end

    for name, t in vim.fs.dir(dir) do
      if t == "directory" then
        local interpreter_path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
        if vim.uv.fs_stat(interpreter_path) then
          coroutine.yield({ locator = self, interpreter_path = interpreter_path })
        end
      end
    end
  end)
end

function Locator:determine_env_var(path)
  return "VIRTUAL_ENV", vim.fs.dirname(vim.fs.dirname(path))
end

return Locator
