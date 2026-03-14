local mock_fs = require("tests.helpers.mock_fs")
local test_utils = require("tests.helpers.test_utils")
local collect = test_utils.collect

describe("_common env_var_strategy", function()
  local common

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({})
    common = require("whichpy.locator._common")
  end)

  after_each(function()
    mock_fs.teardown()
  end)

  describe("virtual_env", function()
    it("should return VIRTUAL_ENV as parent of parent", function()
      local result = common.get_env_var_strategy.virtual_env("/home/user/.venv/bin/python")
      assert.are.same({ name = "VIRTUAL_ENV", val = "/home/user/.venv" }, result)
    end)
  end)

  describe("conda", function()
    it("should return CONDA_PREFIX as grandparent on unix", function()
      local result = common.get_env_var_strategy.conda("/opt/conda/envs/myenv/bin/python")
      assert.are.same({ name = "CONDA_PREFIX", val = "/opt/conda/envs/myenv" }, result)
    end)
  end)

  describe("pyenv", function()
    it("should return VIRTUAL_ENV when pyvenv.cfg exists", function()
      mock_fs.setup({
        ["/home/user/.pyenv/versions/3.11.0/envs/myenv"] = {
          bin = { python = "file" },
          ["pyvenv.cfg"] = "file",
        },
      })

      local result =
        common.get_env_var_strategy.pyenv("/home/user/.pyenv/versions/3.11.0/envs/myenv/bin/python")
      assert.are.same(
        { name = "VIRTUAL_ENV", val = "/home/user/.pyenv/versions/3.11.0/envs/myenv" },
        result
      )
    end)

    it("should return empty table when pyvenv.cfg does not exist", function()
      mock_fs.setup({
        ["/home/user/.pyenv/versions/3.11.0"] = {
          bin = { python = "file" },
        },
      })

      local result =
        common.get_env_var_strategy.pyenv("/home/user/.pyenv/versions/3.11.0/bin/python")
      assert.are.same({}, result)
    end)
  end)

  describe("guess", function()
    it("should detect conda-meta and return CONDA_PREFIX", function()
      mock_fs.setup({
        ["/opt/conda/envs/myenv"] = {
          bin = { python = "file" },
          ["conda-meta"] = {},
        },
      })

      local result = common.get_env_var_strategy.guess("/opt/conda/envs/myenv/bin/python")
      assert.are.same({ name = "CONDA_PREFIX", val = "/opt/conda/envs/myenv" }, result)
    end)

    it("should detect pyvenv.cfg and return VIRTUAL_ENV", function()
      mock_fs.setup({
        ["/home/user/project/.venv"] = {
          bin = { python = "file" },
          ["pyvenv.cfg"] = "file",
        },
      })

      local result = common.get_env_var_strategy.guess("/home/user/project/.venv/bin/python")
      assert.are.same({ name = "VIRTUAL_ENV", val = "/home/user/project/.venv" }, result)
    end)

    it("should return empty table when no markers found", function()
      mock_fs.setup({
        ["/usr/local"] = {
          bin = { python = "file" },
        },
      })

      local result = common.get_env_var_strategy.guess("/usr/local/bin/python")
      assert.are.same({}, result)
    end)
  end)

  describe("no", function()
    it("should return empty table", function()
      assert.are.same({}, common.get_env_var_strategy.no())
    end)
  end)
end)

describe("_common find_interpreters_in_dir", function()
  local common

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({})
    common = require("whichpy.locator._common")
  end)

  after_each(function()
    mock_fs.teardown()
  end)

  local fake_locator = test_utils.make_fake_locator("test", "Test")

  it("should yield interpreters from subdirectories", function()
    mock_fs.setup({
      ["/venvs"] = {
        myenv = { bin = { python = "file" } },
        other = { bin = { python = "file" } },
      },
    })

    local results = collect(common.find_interpreters_in_dir(fake_locator, "/venvs"))
    assert.are.equal(2, #results)
  end)

  it("should yield nothing for empty directory", function()
    mock_fs.setup({
      ["/venvs"] = {},
    })

    local results = collect(common.find_interpreters_in_dir(fake_locator, "/venvs"))
    assert.are.equal(0, #results)
  end)

  it("should skip subdirectories without python binary", function()
    mock_fs.setup({
      ["/venvs"] = {
        myenv = { bin = {} },
        valid = { bin = { python = "file" } },
      },
    })

    local results = collect(common.find_interpreters_in_dir(fake_locator, "/venvs"))
    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("valid/bin/python"))
  end)
end)
