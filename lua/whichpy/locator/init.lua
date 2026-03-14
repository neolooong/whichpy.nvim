local config = require("whichpy.config").config

---@class WhichPy.EnvVar
---@field name? string
---@field val? string

---@class WhichPy.Locator
---@field name string
---@field display_name string
---@field get_env_var_strategy fun(path: string): WhichPy.EnvVar
---@field find fun(self: WhichPy.Locator, Job: WhichPy.SearchJob): fun(): WhichPy.Ctx|WhichPy.InterpreterInfo

---@class WhichPy.Locator.Opts
---@field enable? boolean
---@field display_name? string
---@field get_env_var_strategy? fun(path: string): WhichPy.EnvVar

local M = {}

---@type table<string, WhichPy.Locator>
M.locators = {}

---@param locator_name string
---@param locator_opts WhichPy.Locator.Opts
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

---@param locator_name string
---@return WhichPy.Locator?
function M.get_locator(locator_name)
  local ok, locator = pcall(require, "whichpy.locator." .. locator_name)
  if not ok then
    return
  end
  local opts = config.locator[locator_name] or {}
  opts.enable = nil
  return locator.new(opts)
end

---@class WhichPy.InterpreterInfo
---@field locator_name string
---@field path string
---@field env_var WhichPy.EnvVar
M.InterpreterInfo = {}

---@class WhichPy.InterpreterInfo.NewOpts
---@field locator WhichPy.Locator
---@field path string

---@param opts WhichPy.InterpreterInfo.NewOpts
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
