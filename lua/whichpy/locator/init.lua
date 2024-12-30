---@class Locator
---@field find fun(): async fun()
---@field merge_opts? fun(opts: table)

---@class InterpreterInfo
---@field locator string name of the locator
---@field interpreter_path string

---@type table<string, Locator>
local locators = {}

local M = {}
setmetatable(M, {
  __index = function(_, key)
    local ok, locator = pcall(require, "whichpy.locator." .. key)
    if ok then
      return locator
    end
  end,
})

---@param locator_name string
---@param locator_opts table
M.setup_locator = function(locator_name, locator_opts)
  if locator_opts.enable == false then
    return
  end

  ---@type Locator?
  local locator = M[locator_name]
  if not locator then
    return
  end

  if locator.merge_opts then
    locator.merge_opts(locator_opts)
  end
  locators[locator_name] = locator
end

---@param on_result function
M.iterate = function(on_result)
  for _, locator in pairs(locators) do
    for interpreter_path in locator.find() do
      local env_info = setmetatable(interpreter_path, {
        __tostring = function(t)
          return string.format(
            "(%s) %s",
            t.locator,
            vim.fn.fnamemodify(t.interpreter_path, ":p:~:.")
          )
        end,
      })
      on_result(env_info)
    end
  end
end

return M
