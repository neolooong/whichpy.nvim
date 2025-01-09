---@class Locator
---@field name string
---@field display_name string
---@field merge_opts? fun(opts: table)
---@field find fun(): async fun(): InterpreterInfo
---@field get_env_var fun(path: string): table<string,string>

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
    for interpreter_info in locator:find() do
      on_result(interpreter_info)
    end
  end
end

---@class InterpreterInfo
---@field locator_name Locator
---@field path string
---@field env_var table<string,string>
M.InterpreterInfo = {}

---@param opts any
---@return InterpreterInfo
function M.InterpreterInfo:new(opts)
  return setmetatable({
    locator_name = opts.locator.name,
    path = opts.path,
  }, {
    __tostring = function(tbl)
      return string.format(
        "(%s) %s",
        opts.locator.display_name,
        vim.fn.fnamemodify(tbl.path, ":p:~:.")
      )
    end,
    __index = function(tbl, key)
      if key == "env_var" then
        return opts.locator.get_env_var_strategy(tbl.path)
      end
      return nil
    end,
  })
end

return M
