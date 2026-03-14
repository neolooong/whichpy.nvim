local stub = require("luassert.stub")
local mock_fs = require("tests.helpers.mock_fs")
local collect = require("tests.helpers.test_utils").collect

describe("global locator", function()
  local Locator, common
  local get_search_path_stub

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({ "global" })
    common = require("whichpy.locator._common")
  end)

  after_each(function()
    if get_search_path_stub then
      get_search_path_stub:revert()
    end
    mock_fs.teardown()
  end)

  local function setup_with_stub(dirs)
    get_search_path_stub = stub(common, "get_search_path_entries", function()
      return dirs
    end)
    package.loaded["whichpy.locator.global"] = nil
    Locator = require("whichpy.locator.global")
  end

  it("should find python in PATH directories", function()
    setup_with_stub({ "/usr/bin/", "/usr/local/bin/" })

    mock_fs.setup({
      ["/usr/bin"] = { python = "file" },
      ["/usr/local/bin"] = { python = "file" },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(2, #results)
  end)

  it("should skip directories without python", function()
    setup_with_stub({ "/usr/bin/", "/empty/" })

    mock_fs.setup({
      ["/usr/bin"] = { python = "file" },
      ["/empty"] = {},
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(1, #results)
  end)

  it("should yield nothing for empty PATH", function()
    setup_with_stub({})

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)
end)
