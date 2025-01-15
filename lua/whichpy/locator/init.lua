local config = require("whichpy.config").config

---@class WhichPy.Locator
---@field private name string
---@field display_name string
---@field get_env_var_strategy fun(path: string): table<string,string>

---@class WhichPy.Locator.Opts
---@field display_name? string
---@field get_env_var_strategy? fun(path: string): table<string,string>

local M = {}

---@type table<string, WhichPy.Locator>
M.locators = {}

---@param locator_name string
---@param locator_opts table
M.setup_locator = function(locator_name, locator_opts)
  if locator_opts.enable == false then
    return
  end

  local ok, locator = pcall(require, "whichpy.locator." .. locator_name)
  if not ok then
    return
  end

  M.locators[locator_name] = locator.new(locator_opts)
end

function M.get_locator(locator_name)
  local ok, locator = pcall(require, "whichpy.locator." .. locator_name)
  if not ok then
    return
  end
  local opts = config.locator[locator_name] or {}
  opts.enable = nil
  return locator.new(opts)
end

---@param on_result function
M.iterate = function(on_result)
  for _, locator in pairs(M.locators) do
    ---@diagnostic disable-next-line: undefined-field
    for interpreter_info in locator:find() do
      on_result(interpreter_info)
    end
  end
end

---@class WhichPy.InterpreterInfo
---@field locator_name WhichPy.Locator
---@field path string
---@field env_var table<string,string>
M.InterpreterInfo = {}

---@param opts any
---@return WhichPy.InterpreterInfo
function M.InterpreterInfo:new(opts)
  return setmetatable({
    locator_name = opts.locator.name,
    path = vim.fn.fnamemodify(opts.path, ":p"),
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
