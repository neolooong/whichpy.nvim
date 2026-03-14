local stub = require("luassert.stub")
local mock_fs = require("tests.helpers.mock_fs")
local test_utils = require("tests.helpers.test_utils")

describe("async_find coroutine protocol", function()
  local common
  local executable_stub, system_stub

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({})
    common = require("whichpy.locator._common")

    executable_stub = stub(vim.fn, "executable")
    system_stub = stub(vim, "system")
  end)

  after_each(function()
    executable_stub:revert()
    system_stub:revert()
    mock_fs.teardown()
  end)

  local make_fake_job = test_utils.make_fake_job
  local fake_locator = test_utils.make_fake_locator("test_async", "Test Async")

  it("should return immediately when executable not found", function()
    executable_stub.returns(0)

    local iter = common.async_find({
      locator = fake_locator,
      Job = make_fake_job(),
      cmd = { "notfound", "arg" },
      parse_output = function(stdout)
        return vim.trim(stdout)
      end,
      err_msg = "test error",
      find_fn = common.find_interpreters_in_dir,
    })

    local result = iter()
    assert.is_nil(result)
    assert.spy(system_stub).was.called(0)
  end)

  it("should yield wait marker and call vim.system", function()
    executable_stub.returns(1)
    local captured_callback

    system_stub.invokes(function(_, _, cb)
      captured_callback = cb
    end)

    local Job = make_fake_job()
    local iter = common.async_find({
      locator = fake_locator,
      Job = Job,
      cmd = { "mycmd", "arg" },
      parse_output = function(stdout)
        return vim.trim(stdout)
      end,
      err_msg = "test error",
      find_fn = common.find_interpreters_in_dir,
    })

    local result = iter()
    assert.are.same({ locator_name = "test_async", wait = true }, result)
    assert.is_not_nil(captured_callback)
  end)

  it("should set err in ctx when command fails", function()
    executable_stub.returns(1)
    local captured_callback

    system_stub.invokes(function(_, _, cb)
      captured_callback = cb
    end)

    local Job = make_fake_job()
    local iter = common.async_find({
      locator = fake_locator,
      Job = Job,
      cmd = { "mycmd" },
      parse_output = function(stdout)
        return vim.trim(stdout)
      end,
      err_msg = "test error",
      find_fn = common.find_interpreters_in_dir,
    })

    iter() -- consume wait marker
    captured_callback({ code = 1, stdout = "", stderr = "fail" })

    assert.are.equal("test error", Job.continued_with.err)
  end)

  it("should set co in ctx when command succeeds", function()
    executable_stub.returns(1)
    local captured_callback

    system_stub.invokes(function(_, _, cb)
      captured_callback = cb
    end)

    mock_fs.setup({
      ["/venvs"] = {
        myenv = { bin = { python = "file" } },
      },
    })

    local Job = make_fake_job()
    local iter = common.async_find({
      locator = fake_locator,
      Job = Job,
      cmd = { "mycmd" },
      parse_output = function(stdout)
        return vim.trim(stdout)
      end,
      err_msg = "test error",
      find_fn = common.find_interpreters_in_dir,
    })

    iter() -- consume wait marker
    captured_callback({ code = 0, stdout = "/venvs\n", stderr = "" })

    assert.is_not_nil(Job.continued_with.co)
    assert.is_nil(Job.continued_with.err)
  end)

  it("should not set co when parse_output returns nil", function()
    executable_stub.returns(1)
    local captured_callback

    system_stub.invokes(function(_, _, cb)
      captured_callback = cb
    end)

    local Job = make_fake_job()
    local iter = common.async_find({
      locator = fake_locator,
      Job = Job,
      cmd = { "mycmd" },
      parse_output = function(_)
        return nil
      end,
      err_msg = "test error",
      find_fn = common.find_interpreters_in_dir,
    })

    iter()
    captured_callback({ code = 0, stdout = "bad output", stderr = "" })

    assert.is_nil(Job.continued_with.co)
    assert.is_nil(Job.continued_with.err)
  end)
end)

describe("async locator configurations", function()
  local executable_stub, system_stub

  before_each(function()
    mock_fs.init_config()
    mock_fs.reload_locator_modules({ "poetry", "pdm", "uv", "conda" })

    executable_stub = stub(vim.fn, "executable", 1)
    system_stub = stub(vim, "system")
    ---@diagnostic disable-next-line: undefined-field
    system_stub.invokes(function(_, _, _) end)
  end)

  after_each(function()
    executable_stub:revert()
    system_stub:revert()
    mock_fs.teardown()
  end)

  it("poetry should use correct command", function()
    local Locator = require("whichpy.locator.poetry")
    local locator = Locator.new()
    local iter = locator:find(test_utils.make_noop_job())
    iter() -- trigger vim.system

    assert.spy(system_stub).was.called(1)
    local call_args = system_stub.calls[1].refs
    assert.are.same({ "poetry", "config", "virtualenvs.path" }, call_args[1])
  end)

  it("pdm should use correct command", function()
    local Locator = require("whichpy.locator.pdm")
    local locator = Locator.new()
    local iter = locator:find(test_utils.make_noop_job())
    iter()

    assert.spy(system_stub).was.called(1)
    local call_args = system_stub.calls[1].refs
    assert.are.same({ "pdm", "config", "venv.location" }, call_args[1])
  end)

  it("uv should use correct command", function()
    local Locator = require("whichpy.locator.uv")
    local locator = Locator.new()
    local iter = locator:find(test_utils.make_noop_job())
    iter()

    assert.spy(system_stub).was.called(1)
    local call_args = system_stub.calls[1].refs
    assert.are.same({ "uv", "python", "dir" }, call_args[1])
  end)

  it("conda should use correct command", function()
    local Locator = require("whichpy.locator.conda")
    local locator = Locator.new()
    local iter = locator:find(test_utils.make_noop_job())
    iter()

    assert.spy(system_stub).was.called(1)
    local call_args = system_stub.calls[1].refs
    assert.are.same({ "conda", "info", "--json" }, call_args[1])
  end)

  it("conda should parse JSON envs correctly", function()
    local captured_callback

    system_stub.invokes(function(_, _, cb)
      captured_callback = cb
    end)

    mock_fs.setup({
      ["/opt/conda/envs/myenv"] = {
        bin = { python = "file" },
      },
    })

    local Locator = require("whichpy.locator.conda")
    local locator = Locator.new()
    local job = test_utils.make_fake_job()

    local iter = locator:find(job)
    iter()

    captured_callback({
      code = 0,
      stdout = vim.json.encode({ envs = { "/opt/conda/envs/myenv" } }),
      stderr = "",
    })

    assert.is_not_nil(job.continued_with.co)

    local results = {}
    for info in job.continued_with.co() do
      results[#results + 1] = info
    end
    assert.are.equal(1, #results)
    assert.is_truthy(results[1].path:find("myenv/bin/python"))
  end)
end)
