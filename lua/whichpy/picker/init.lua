---@class WhichPy.Picker
---@field setup function
---@field show function

local M = {}
setmetatable(M, {
  __index = function(_, key)
    if key == "fzf-lua" or key == "telescope" then
      if require("whichpy.util").is_support(key) then
        return require("whichpy.picker." .. key)
      end
      require("whichpy.util").notify_warn(
        "Can't require " .. key .. ". Please check plugin installed."
      )
    elseif key ~= "builtin" then
      require("whichpy.util").notify_warn("Invalid picker: " .. key .. "\nFallback to builtin.")
    end
    return require("whichpy.picker.builtin")
  end,
})

return M
