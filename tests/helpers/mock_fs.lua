local stub = require("luassert.stub")

local M = {}

-- Flattened file system: { ["/a/b/c"] = "file", ["/a/b"] = "directory", ... }
local _flat = {}
local _stubs = {}

--- Flatten a nested tree into absolute paths.
---@param tree table
local function flatten(tree)
  local result = {}
  for abs_path, children in pairs(tree) do
    result[abs_path] = "directory"
    local function walk(dir, node)
      for name, val in pairs(node) do
        local full = vim.fs.joinpath(dir, name)
        if val == "file" then
          result[full] = "file"
        elseif type(val) == "table" then
          result[full] = "directory"
          walk(full, val)
        end
      end
    end
    walk(abs_path, children)
  end
  return result
end

--- Remove trailing slash from path (keep root "/" as-is).
---@param path string
---@return string
local function normalize(path)
  if #path > 1 and path:sub(-1) == "/" then
    return path:sub(1, -2)
  end
  return path
end

--- Get immediate children of a directory path.
--- Expects a normalized path (no trailing slash, except root "/").
---@param dir string
---@return {name: string, type: string}[]
local function get_children(dir)
  local children = {}
  local prefix = dir == "/" and "/" or (dir .. "/")
  for path, ftype in pairs(_flat) do
    if vim.startswith(path, prefix) then
      local rest = path:sub(#prefix + 1)
      if not rest:find("/") then
        children[#children + 1] = { name = rest, type = ftype }
      end
    end
  end
  table.sort(children, function(a, b)
    return a.name < b.name
  end)
  return children
end

--- Install mock filesystem stubs.
---@param tree table Nested table: key=absolute path, value=table (dir) or "file"
function M.setup(tree)
  _flat = flatten(tree)

  -- vim.uv.fs_scandir
  _stubs[#_stubs + 1] = stub(vim.uv, "fs_scandir", function(path)
    local norm = normalize(path)
    if _flat[norm] ~= "directory" then
      return nil
    end
    return { entries = get_children(norm), cursor = 1 }
  end)

  -- vim.uv.fs_scandir_next
  _stubs[#_stubs + 1] = stub(vim.uv, "fs_scandir_next", function(state)
    if state == nil or state.cursor > #state.entries then
      return nil
    end
    local entry = state.entries[state.cursor]
    state.cursor = state.cursor + 1
    return entry.name, entry.type
  end)

  -- vim.uv.fs_stat
  _stubs[#_stubs + 1] = stub(vim.uv, "fs_stat", function(path)
    local ftype = _flat[normalize(path)]
    if ftype then
      return { type = ftype }
    end
    return nil
  end)

  -- vim.fs.dir
  _stubs[#_stubs + 1] = stub(vim.fs, "dir", function(path)
    local children = get_children(normalize(path))
    local i = 0
    return function()
      i = i + 1
      if i > #children then
        return nil
      end
      return children[i].name, children[i].type
    end
  end)
end

--- Revert all stubs.
function M.teardown()
  for _, s in ipairs(_stubs) do
    s:revert()
  end
  _stubs = {}
  _flat = {}
end

--- Reload locator modules so they pick up fresh config and stubs.
--- Call AFTER setting up config and any stubs on _common.
---@param modules string[] Module names to reload (e.g., {"workspace", "global"})
function M.reload_locator_modules(modules)
  package.loaded["whichpy.locator._common"] = nil
  for _, name in ipairs(modules) do
    package.loaded["whichpy.locator." .. name] = nil
  end
end

--- Initialize minimal config needed for tests.
function M.init_config()
  require("whichpy.config").config = {
    update_path_env = false,
    lsp = {},
    locator = {},
  }
end

return M
