local stub = require("luassert.stub")
local mock_fs = require("tests.helpers.mock_fs")
local collect = require("tests.helpers.test_utils").collect

describe("global_virtual_environment locator", function()
  local Locator, common

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({ "global_virtual_environment" })
    common = require("whichpy.locator._common")
  end)

  after_each(function()
    if common.get_global_virtual_environment_dirs.revert then
      common.get_global_virtual_environment_dirs:revert()
    end
    mock_fs.teardown()
  end)

  local function setup_with_stub(dirs)
    stub(common, "get_global_virtual_environment_dirs", function()
      return dirs
    end)
    package.loaded["whichpy.locator.global_virtual_environment"] = nil
    Locator = require("whichpy.locator.global_virtual_environment")
  end

  it("should find venvs in global dirs", function()
    setup_with_stub({ "/home/user/.venvs/" })

    mock_fs.setup({
      ["/home/user/.venvs"] = {
        myproject = { bin = { python = "file" } },
      },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("myproject/bin/python"))
  end)

  it("should skip subdirectories without python binary", function()
    setup_with_stub({ "/home/user/.venvs/" })

    mock_fs.setup({
      ["/home/user/.venvs"] = {
        myproject = { bin = {} },
        valid = { bin = { python = "file" } },
      },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("valid/bin/python"))
  end)

  it("should yield nothing for empty global dirs", function()
    setup_with_stub({})

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)
end)
