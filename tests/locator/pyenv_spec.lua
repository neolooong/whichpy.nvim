local stub = require("luassert.stub")
local mock_fs = require("tests.helpers.mock_fs")
local collect = require("tests.helpers.test_utils").collect

describe("pyenv locator", function()
  local Locator, common

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({ "pyenv" })
    common = require("whichpy.locator._common")

    stub(common, "get_pyenv_version_dir", function()
      return "/home/user/.pyenv/versions"
    end)

    package.loaded["whichpy.locator.pyenv"] = nil
    Locator = require("whichpy.locator.pyenv")
  end)

  after_each(function()
    common.get_pyenv_version_dir:revert()
    mock_fs.teardown()
  end)

  it("should find envs/ venvs when venv_only=true", function()
    mock_fs.setup({
      ["/home/user/.pyenv/versions"] = {
        ["3.11.0"] = {
          bin = { python = "file" },
          envs = {
            myenv = { bin = { python = "file" } },
          },
        },
      },
    })

    local locator = Locator.new({ venv_only = true })
    local results = collect(locator:find())

    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("envs/myenv/bin/python"))
  end)

  it("should skip base interpreter when venv_only=true", function()
    mock_fs.setup({
      ["/home/user/.pyenv/versions"] = {
        ["3.11.0"] = {
          bin = { python = "file" },
          envs = {},
        },
      },
    })

    local locator = Locator.new({ venv_only = true })
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)

  it("should find base and venvs when venv_only=false", function()
    mock_fs.setup({
      ["/home/user/.pyenv/versions"] = {
        ["3.11.0"] = {
          bin = { python = "file" },
          envs = {
            myenv = { bin = { python = "file" } },
          },
        },
      },
    })

    local locator = Locator.new({ venv_only = false })
    local results = collect(locator:find())

    assert.are.equal(2, #results)
  end)

  it("should handle multiple versions with multiple venvs", function()
    mock_fs.setup({
      ["/home/user/.pyenv/versions"] = {
        ["3.11.0"] = {
          bin = { python = "file" },
          envs = {
            env1 = { bin = { python = "file" } },
          },
        },
        ["3.12.0"] = {
          bin = { python = "file" },
          envs = {
            env2 = { bin = { python = "file" } },
            env3 = { bin = { python = "file" } },
          },
        },
      },
    })

    local locator = Locator.new({ venv_only = false })
    local results = collect(locator:find())

    -- 2 base + 3 venvs = 5
    assert.are.equal(5, #results)
  end)

  it("should yield nothing when no versions exist", function()
    mock_fs.setup({
      ["/home/user/.pyenv/versions"] = {},
    })

    local locator = Locator.new()
    local results = collect(locator:find())

    assert.are.equal(0, #results)
  end)
end)
