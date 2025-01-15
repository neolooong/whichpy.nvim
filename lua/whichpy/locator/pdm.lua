local get_interpreter_path = require("whichpy.util").get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local get_pdm_venv_location = require("whichpy.locator._common").get_pdm_venv_location
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---@class WhichPy.Locator.Pdm: WhichPy.Locator

---@class WhichPy.Locator.Pdm.Opts

local Locator = { name = "pdm" }
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "PDM",
    get_env_var_strategy = get_env_var_strategy.virtual_env,
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find()
  local dir = get_pdm_venv_location()

  return coroutine.wrap(function()
    if not dir then
      return
    end

    for name, t in vim.fs.dir(dir) do
      if t == "directory" then
        local path = get_interpreter_path(vim.fs.joinpath(dir, name), "bin")
        if vim.uv.fs_stat(path) then
          coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
        end
      end
    end
  end)
end

return Locator
