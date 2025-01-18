---@class WhichPy.Ctx
---@field locator_name string
---@field wait? boolean
---@field err? string
---@field co? thread

local util = require("whichpy.util")
local locators = require("whichpy.locator").locators

local SearchJob = {
  co = nil,
  _temp_envs = {},
  on_result = function(_) end,
  on_finish = function() end,
}

---@return "dead"|"normal"|"running"|"suspended"|nil
function SearchJob:status()
  return (self.co and coroutine.status(self.co)) or nil
end

function SearchJob:start()
  if self.co ~= nil and self.status(self) ~= "dead" then
    return
  end

  coroutine.wrap(function()
    self.co = coroutine.running()
    self._temp_envs = {}

    local wait_group = {}
    for _, locator in pairs(locators) do
      ---@param ctx WhichPy.Ctx|WhichPy.InterpreterInfo
      ---@diagnostic disable-next-line: undefined-field
      for ctx in locator:find(self) do
        if ctx.wait then
          wait_group[ctx.locator_name] = true
        else
          table.insert(self._temp_envs, ctx)
          if self.on_result then
            self.on_result(ctx)
          end
        end
      end
    end

    while not vim.tbl_isempty(wait_group) do
      ---@type WhichPy.Ctx
      local ctx = coroutine.yield()
      if ctx.err ~= nil then
        vim.schedule(function()
          util.notify(ctx.err, { level = vim.log.levels.ERROR })
        end)
      elseif ctx.co then
        for info in ctx.co() do
          table.insert(self._temp_envs, info)
          if self.on_result then
            self.on_result(info)
          end
        end
      end
      if not ctx.wait then
        wait_group[ctx.locator_name] = nil
      end
    end

    require("whichpy.envs").set_envs(self._temp_envs)
    self.on_finish()
    self.update_hook(self, nil, nil)
  end)()
end

function SearchJob:update_hook(on_result, on_finish)
  self.on_result = on_result or function(_) end
  self.on_finish = on_finish or function() end
end

---@param ctx WhichPy.Ctx
function SearchJob:continue(ctx)
  coroutine.resume(self.co, ctx)
end

return SearchJob
