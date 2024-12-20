local is_win = vim.uv.os_uname().sysname == "Windows_NT"
local bin_scripts = (is_win and "Scripts") or "bin"
local filename = (is_win and "python.exe") or "python"

local M = {}

M._notify = function(msg, lvl)
  vim.notify(msg, lvl, {
    -- rcarriga/nvim-notify
    title = "whichpy",

    -- j-hui/fidget.nvim
    annote = "whichpy",
  })
end

M.notify_info = function(msg)
  M._notify(msg, vim.log.levels.INFO)
end

M.notify_error = function(msg)
  M._notify(msg, vim.log.levels.ERROR)
end

M.notify_warn = function(msg)
  M._notify(msg, vim.log.levels.WARN)
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

---@param dir string
---@param case "root" | "bin"
---@return string
M.get_interpreter_path = function(dir, case)
  return vim.fs.joinpath(dir, case == "root" and "" or bin_scripts, filename)
end

---@param plugin "fzf-lua"
M.is_support = function (plugin)
  return pcall(require, plugin)
end

return M
