local util = require("whichpy.util")
local is_win = util.is_win
local get_interpreter_path = util.get_interpreter_path
local get_env_var_strategy = require("whichpy.locator._common").get_env_var_strategy
local InterpreterInfo = require("whichpy.locator").InterpreterInfo

---@class WhichPy.Locator.Conda: WhichPy.Locator

---@class WhichPy.Locator.Conda.Opts

local Locator = { name = "conda" }
Locator.__index = Locator

function Locator.new(opts)
  local obj = vim.tbl_deep_extend("force", {
    display_name = "Conda",
    get_env_var_strategy = get_env_var_strategy.conda_prefix,
  }, opts or {})
  return setmetatable(obj, Locator)
end

function Locator:find(Job)
  return coroutine.wrap(function()
    if not vim.fn.executable("conda") then
      return
    end

    vim.system({ "conda", "info", "--json" }, {}, function(out)
      local ctx = { locator_name = self.name }

      if out.code ~= 0 then
        ctx.err = "conda command error"
      else
        local ok, envs = pcall(vim.json.decode, out.stdout)
        if ok then
          envs = envs.envs
          if envs then
            ctx.co = function()
              return self:_find(envs)
            end
          end
        else
          ctx.err = "conda output isn't json."
        end
      end

      Job:continue(ctx)
    end)

    coroutine.yield({ locator_name = self.name, wait = true })
  end)
end

function Locator:_find(envs)
  return coroutine.wrap(function()
    for _, env in ipairs(envs) do
      local path = get_interpreter_path(env, is_win and "root" or "bin")
      if vim.uv.fs_stat(path) then
        coroutine.yield(InterpreterInfo:new({ locator = self, path = path }))
      end
    end
  end)
end

return Locator
