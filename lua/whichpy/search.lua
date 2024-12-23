local async = require("whichpy.async")
local locator = require("whichpy.locator")
local util = require("whichpy.util")

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

  async.run(function()
    self.co = coroutine.running()
    self._temp_envs = {}
    locator.iterate(function(env_info)
      table.insert(self._temp_envs, env_info)
      if self.on_result then
        self.on_result(env_info)
      end
    end)
  end, function()
    vim.schedule(function()
      util.notify("Search completed.")
    end)
    require("whichpy.envs").set_envs(self._temp_envs)
    self.on_finish()
    self.update_hook(self, nil, nil)
  end)
end

function SearchJob:update_hook(on_result, on_finish)
  self.on_result = on_result or function(_) end
  self.on_finish = on_finish or function() end
end

return SearchJob
