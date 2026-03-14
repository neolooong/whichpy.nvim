local util = require("whichpy.util")

local M = {}

---@param cache_dir string
---@return string
local function cache_filename(cache_dir)
  local filename = vim.fn.getcwd():gsub("[\\/:]+", "%%")
  return vim.fs.joinpath(cache_dir, filename)
end

---@param cache_dir string
---@param interpreter_path string
---@param locator_name string
function M.save(cache_dir, interpreter_path, locator_name)
  vim.fn.mkdir(cache_dir, "p")
  local f, err = io.open(cache_filename(cache_dir), "wb")
  if f then
    f:write(interpreter_path .. "\n" .. locator_name)
    f:close()
  else
    util.notify("Failed to write cache: " .. err, { level = vim.log.levels.WARN })
  end
end

---@param cache_dir string
---@return string? path
---@return string? locator_name
function M.load(cache_dir)
  local f = io.open(cache_filename(cache_dir), "r")
  if not f then
    return nil, nil
  end
  local lines = {}
  local line = f:read()
  while line do
    table.insert(lines, line)
    line = f:read()
  end
  f:close()
  return lines[1], lines[2]
end

---@param cache_dir string
function M.remove(cache_dir)
  os.remove(cache_filename(cache_dir))
end

return M
