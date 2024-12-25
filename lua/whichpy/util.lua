local is_win = (vim.uv or vim.loop).os_uname().sysname == "Windows_NT"
local bin_scripts = (is_win and "Scripts") or "bin"
local filename = (is_win and "python.exe") or "python"

local M = {}

---@class (exact) WhichPy.NotifyOpt
---@field once boolean|nil defaults to false
---@field level integer|nil defaults to vim.log.levels.INFO

---@param msg string
---@param opts? WhichPy.NotifyOpt
M.notify = function(msg, opts)
  local notify_func = vim.notify
  local level = vim.log.levels.INFO
  opts = vim.tbl_deep_extend("force", opts or {}, {
    title = "whichpy", -- rcarriga/nvim-notify
    annote = "whichpy", -- j-hui/fidget.nvim
  })
  if opts.once then
    notify_func = vim.notify_once
    opts.once = nil
  end
  if not opts.level then
    level = opts.level
    opts.level = nil
  end
  notify_func(msg, level, opts)
end

M.deduplicate = function(tbl)
  local hash = {}
  local unique_tbl = {}
  for _, value in pairs(tbl) do
    if hash[value] == nil then
      hash[value] = true
      unique_tbl[#unique_tbl + 1] = value
    end
  end
  return unique_tbl
end

M.joinpath = function(...)
  if vim.fs.joinpath then
    return vim.fs.joinpath(...)
  end
  return (table.concat({ ... }, "/"):gsub("//+", "/"))
end

---@param dir string
---@param case "root" | "bin"
---@return string
M.get_interpreter_path = function(dir, case)
  return M.joinpath(dir, case == "root" and "" or bin_scripts, filename)
end

---@param plugin "fzf-lua"|"telescope"
M.is_support = function(plugin)
  return pcall(require, plugin)
end

M.list_contains = function(...)
  if vim.list_contains then
    vim.list_contains(...)
  end
  ---@diagnostic disable-next-line: unbalanced-assignments
  local t, value = unpack({ ... })
  for _, v in ipairs(t) do
    if v == value then
      return true
    end
  end
  return false
end

return M
