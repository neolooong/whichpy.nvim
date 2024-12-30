local M = {}
M.is_win = vim.uv.os_uname().sysname == "Windows_NT"
M.bin_scripts = (M.is_win and "Scripts") or "bin"
M.filename = (M.is_win and "python.exe") or "python"

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

---@param dir string
---@param case "root" | "bin"
---@return string
M.get_interpreter_path = function(dir, case)
  return vim.fs.joinpath(dir, case == "root" and "" or M.bin_scripts, M.filename)
end

---@param plugin "fzf-lua"|"telescope"
M.is_support = function(plugin)
  return pcall(require, plugin)
end

return M
