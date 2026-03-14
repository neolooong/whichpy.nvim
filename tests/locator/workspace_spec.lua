local stub = require("luassert.stub")
local mock_fs = require("tests.helpers.mock_fs")
local collect = require("tests.helpers.test_utils").collect

describe("workspace locator", function()
  local Locator, common
  local get_workspace_folders_stub

  before_each(function()
    mock_fs.init_config()

    -- Reload _common to pick up fresh config
    mock_fs.reload_locator_modules({ "workspace" })
    common = require("whichpy.locator._common")

    -- Stub BEFORE reloading workspace so it captures the stubbed version
    get_workspace_folders_stub = stub(common, "get_workspace_folders", function()
      return { "/project" }
    end)

    -- Reload workspace to capture stubbed get_workspace_folders
    package.loaded["whichpy.locator.workspace"] = nil
    Locator = require("whichpy.locator.workspace")
  end)

  after_each(function()
    get_workspace_folders_stub:revert()
    mock_fs.teardown()
  end)

  it("should find .venv in workspace root", function()
    mock_fs.setup({
      ["/project"] = {
        [".venv"] = { bin = { python = "file" } },
      },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("%.venv/bin/python"))
  end)

  it("should find multiple venvs", function()
    mock_fs.setup({
      ["/project"] = {
        [".venv"] = { bin = { python = "file" } },
        [".env"] = { bin = { python = "file" } },
      },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(2, #results)
  end)

  it("should respect depth limit", function()
    mock_fs.setup({
      ["/project"] = {
        sub1 = {
          sub2 = {
            [".venv"] = { bin = { python = "file" } },
          },
        },
      },
    })

    local locator = Locator.new({ depth = 2 })
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)

  it("should ignore .git, __pycache__ and other ignore_dirs", function()
    mock_fs.setup({
      ["/project"] = {
        [".git"] = { env = { bin = { python = "file" } } },
        __pycache__ = { env = { bin = { python = "file" } } },
      },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)

  it("should skip directories without python binary", function()
    mock_fs.setup({
      ["/project"] = {
        [".venv"] = { bin = {} },
      },
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)

  it("should find venvs in subdirectories within depth limit", function()
    mock_fs.setup({
      ["/project"] = {
        subdir = {
          [".env"] = { bin = { python = "file" } },
        },
      },
    })

    local locator = Locator.new({ depth = 2 })
    local results = collect(locator:find())

    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("subdir/%.env/bin/python"))
  end)

  it("should yield nothing for empty workspace", function()
    mock_fs.setup({
      ["/project"] = {},
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)
end)
