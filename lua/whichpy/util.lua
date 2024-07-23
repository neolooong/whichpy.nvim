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

return M
