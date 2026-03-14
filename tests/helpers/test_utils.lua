local M = {}

--- Consume an iterator and collect all results into a table.
---@param iter function
---@return table[]
function M.collect(iter)
  local results = {}
  for info in iter do
    results[#results + 1] = info
  end
  return results
end

--- Create a fake job with `continued_with` state tracking.
---@return table
function M.make_fake_job()
  local job = { continued_with = nil }
  function job:continue(ctx)
    self.continued_with = ctx
  end
  return job
end

--- Create a no-op fake job (continue does nothing).
---@return table
function M.make_noop_job()
  local job = {}
  function job:continue(_) end
  return job
end

--- Create a fake locator mock with the given name and display_name.
---@param name string
---@param display_name string
---@return table
function M.make_fake_locator(name, display_name)
  return {
    name = name,
    display_name = display_name,
    get_env_var_strategy = function()
      return {}
    end,
  }
end

return M
