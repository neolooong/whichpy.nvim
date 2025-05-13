local get_interpreter_path = require("whichpy.util").get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---@class WhichPy.Locator.Uv: WhichPy.Locator

---@class WhichPy.Locator.Uv.Opts

local Locator = { name = "uv" }
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "uv",
    get_env_var_strategy = get_env_var_strategy.no,
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find(Job)
  return coroutine.wrap(function()
    if vim.fn.executable("uv") == 0 then
      return
    end

    vim.system({ "uv", "python", "dir" }, {}, function(out)
      local ctx = { locator_name = self.name }

      if out.code ~= 0 then
        ctx.err = "uv command error"
      else
        local dir = vim.trim(out.stdout)
        if dir ~= "" then
          ctx.co = function()
            return self:_find(dir)
          end
        end
      end

      Job:continue(ctx)
    end)

    coroutine.yield({ locator_name = self.name, wait = true })
  end)
end

function Locator:_find(dir)
  return coroutine.wrap(function()
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
