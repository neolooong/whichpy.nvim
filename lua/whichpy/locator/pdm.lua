local get_interpreter_path = require("whichpy.util").get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_pdm_venv_location = require("whichpy.locator._common").get_pdm_venv_location

local Locator = {
  name = "pdm",
  display_name = "PDM",
  get_env_var = get_env_var_strategy.guess,
}

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

return Locator
