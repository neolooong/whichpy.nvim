local stub = require("luassert.stub")
local mock_fs = require("tests.helpers.mock_fs")
local locator_mod = require("whichpy.locator")
local InterpreterInfo = locator_mod.InterpreterInfo

local function make_sync_locator(name, paths)
  local locator = {
    name = name,
    display_name = name,
    get_env_var_strategy = function()
      return {}
    end,
  }
  locator.find = function(_)
    return coroutine.wrap(function()
      for _, path in ipairs(paths) do
        coroutine.yield(InterpreterInfo:new({ locator = locator, path = path }))
      end
    end)
  end
  return locator
end

local function make_async_locator(name)
  local locator = {
    name = name,
    display_name = name,
    get_env_var_strategy = function()
      return {}
    end,
  }
  locator.find = function(_)
    return coroutine.wrap(function()
      coroutine.yield({ locator_name = name, wait = true })
    end)
  end
  return locator
end

local function make_async_ctx(locator, paths)
  return {
    locator_name = locator.name,
    co = function()
      return coroutine.wrap(function()
        for _, path in ipairs(paths) do
          coroutine.yield(InterpreterInfo:new({ locator = locator, path = path }))
        end
      end)
    end,
  }
end

describe("SearchJob", function()
  local SearchJob = require("whichpy.search")
  local original_locators
  local set_envs_stub

  before_each(function()
    original_locators = {}
    for k, v in pairs(locator_mod.locators) do
      original_locators[k] = v
    end
    -- Clear all locators
    for k in pairs(locator_mod.locators) do
      locator_mod.locators[k] = nil
    end

    SearchJob.co = nil
    SearchJob._temp_envs = {}

    set_envs_stub = stub(require("whichpy.envs"), "set_envs")
  end)

  after_each(function()
    -- Restore original locators
    for k in pairs(locator_mod.locators) do
      locator_mod.locators[k] = nil
    end
    for k, v in pairs(original_locators) do
      locator_mod.locators[k] = v
    end

    set_envs_stub:revert()
    mock_fs.teardown()
  end)

  it("should collect all results from sync locators", function()
    mock_fs.setup({
      ["/a/bin"] = { python = "file" },
      ["/b/bin"] = { python = "file" },
      ["/c/bin"] = { python = "file" },
    })

    locator_mod.locators["loc1"] = make_sync_locator("loc1", { "/a/bin/python", "/b/bin/python" })
    locator_mod.locators["loc2"] = make_sync_locator("loc2", { "/c/bin/python" })

    local finished = false
    SearchJob:update_hook(nil, function()
      finished = true
    end)
    SearchJob:start()

    assert.is_true(finished)
    assert.are.equal(3, #SearchJob._temp_envs)
    assert.spy(set_envs_stub).was.called(1)
  end)

  it("should trigger on_result for each result", function()
    mock_fs.setup({
      ["/a/bin"] = { python = "file" },
      ["/b/bin"] = { python = "file" },
    })

    locator_mod.locators["loc1"] = make_sync_locator("loc1", { "/a/bin/python", "/b/bin/python" })

    local result_count = 0
    SearchJob:update_hook(function(_)
      result_count = result_count + 1
    end, nil)
    SearchJob:start()

    assert.are.equal(2, result_count)
  end)

  it("should call on_finish exactly once", function()
    locator_mod.locators["loc1"] = make_sync_locator("loc1", {})

    local finish_count = 0
    SearchJob:update_hook(nil, function()
      finish_count = finish_count + 1
    end)
    SearchJob:start()

    assert.are.equal(1, finish_count)
  end)

  it("should handle async locator success", function()
    mock_fs.setup({
      ["/async/bin"] = { python = "file" },
    })

    local async_loc = make_async_locator("async1")
    locator_mod.locators["async1"] = async_loc

    local finished = false
    SearchJob:update_hook(nil, function()
      finished = true
    end)
    SearchJob:start()

    assert.is_false(finished)

    SearchJob:continue(make_async_ctx(async_loc, { "/async/bin/python" }))

    assert.is_true(finished)
    assert.are.equal(1, #SearchJob._temp_envs)
  end)

  it("should handle async locator error", function()
    local async_loc = make_async_locator("async_err")
    locator_mod.locators["async_err"] = async_loc

    local notify_stub = stub(vim, "schedule")

    local finished = false
    SearchJob:update_hook(nil, function()
      finished = true
    end)
    SearchJob:start()

    assert.is_false(finished)

    SearchJob:continue({ locator_name = "async_err", err = "command failed" })

    assert.is_true(finished)
    assert.are.equal(0, #SearchJob._temp_envs)

    notify_stub:revert()
  end)

  it("should collect results from sync and async locators", function()
    mock_fs.setup({
      ["/sync/bin"] = { python = "file" },
      ["/async/bin"] = { python = "file" },
    })

    locator_mod.locators["sync1"] = make_sync_locator("sync1", { "/sync/bin/python" })

    local async_loc = make_async_locator("async1")
    locator_mod.locators["async1"] = async_loc

    local finished = false
    SearchJob:update_hook(nil, function()
      finished = true
    end)
    SearchJob:start()

    assert.is_false(finished)
    assert.are.equal(1, #SearchJob._temp_envs)

    SearchJob:continue(make_async_ctx(async_loc, { "/async/bin/python" }))

    assert.is_true(finished)
    assert.are.equal(2, #SearchJob._temp_envs)
  end)
end)
