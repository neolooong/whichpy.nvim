local util = require("whichpy.util")

---@class WhichPy.Picker
---@field setup fun(self: WhichPy.Picker): table
---@field show fun(self: WhichPy.Picker)

local M = {}
setmetatable(M, {
  __index = function(_, key)
    if key == "fzf-lua" or key == "telescope" or key == "snacks" then
      if util.is_support(key) then
        return require("whichpy.picker." .. key)
      end
      util.notify(
        "Can't require " .. key .. ". Please check plugin installed. Fallback to builtin",
        { once = true, level = vim.log.levels.WARN }
      )
    elseif key ~= "builtin" then
      util.notify(
        "Invalid picker: '" .. key .. "'. Fallback to builtin.",
        { once = true, level = vim.log.levels.WARN }
      )
    end
    return require("whichpy.picker.builtin")
  end,
})

return M
