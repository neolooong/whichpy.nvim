local M = {}

local locators = {}

---@param locator_name string
---@param locator_opts table
M.setup_locator = function(locator_name, locator_opts)
  local ok, locator = pcall(require, "whichpy.locator." .. locator_name)
  if not ok then
    require("whichpy.util").notify_error(locator_name .. " isn't a definded locator.")
    return
  end
  if locator_opts.enable == false then
    return
  end
  if locator.merge_opts then
    locator.merge_opts(locator_opts)
  end
  table.insert(locators, locator)
end

---@param on_result function
M.iterate = function(on_result)
  for _, locator in pairs(locators) do
    for interpreter_path in locator.find() do
      on_result(locator.resolve(interpreter_path))
    end
  end
end

return M
