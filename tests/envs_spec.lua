---@diagnostic disable: undefined-field
local mock = require("luassert.mock")
local stub = require("luassert.stub")
local match = require("luassert.match")

local function new_fake_handler()
  local handler = {}
  function handler:snapshot_settings(_) end
  function handler:restore_snapshot(_) end
  function handler:set_python_path(_, _) end
  return handler
end

local function make_selected(path, env_var)
  env_var = env_var or {}
  return {
    path = path,
    locator_name = "test",
    env_var = env_var,
  }
end

describe("envs", function()
  local envs
  local handler1
  local saved_virtual_env, saved_conda_prefix, saved_path

  before_each(function()
    saved_virtual_env = vim.env.VIRTUAL_ENV
    saved_conda_prefix = vim.env.CONDA_PREFIX
    saved_path = vim.env.PATH

    handler1 = mock(new_fake_handler())

    package.loaded["whichpy.envs"] = nil
    package.loaded["whichpy.cache"] = nil

    require("whichpy.config").config = {
      update_path_env = false,
      lsp = { srv1 = handler1 },
      locator = {},
      cache_dir = vim.fn.tempname(),
      after_handle_select = nil,
    }

    stub(vim.lsp, "get_clients", function(opts)
      if opts.name == "srv1" then
        return { { name = "srv1", id = 1 } }
      end
      return {}
    end)

    envs = require("whichpy.envs")
  end)

  after_each(function()
    vim.env.VIRTUAL_ENV = saved_virtual_env
    vim.env.CONDA_PREFIX = saved_conda_prefix
    vim.env.PATH = saved_path

    mock.revert(handler1)
    vim.lsp.get_clients:revert()

    vim.fn.delete(require("whichpy.config").config.cache_dir, "rf")
  end)

  describe("handle_select", function()
    it("should set current_selected to the selected path", function()
      envs.handle_select(make_selected("/usr/bin/python3"), false)
      assert.are.equal("/usr/bin/python3", envs.current_selected())
    end)

    it("should snapshot LSP on first select only", function()
      envs.handle_select(make_selected("/usr/bin/python3"), false)
      assert.spy(handler1.snapshot_settings).was.called(1)
      assert.spy(handler1.set_python_path).was.called(1)

      envs.handle_select(make_selected("/other/python"), false)
      assert.spy(handler1.snapshot_settings).was.called(1)
      assert.spy(handler1.set_python_path).was.called(2)
    end)

    it("should set VIRTUAL_ENV when env_var is VIRTUAL_ENV", function()
      envs.handle_select(
        make_selected("/home/.venv/bin/python", { name = "VIRTUAL_ENV", val = "/home/.venv" }),
        false
      )
      assert.are.equal("/home/.venv", vim.env.VIRTUAL_ENV)
      assert.is_nil(vim.env.CONDA_PREFIX)
    end)

    it("should set CONDA_PREFIX when env_var is CONDA_PREFIX", function()
      envs.handle_select(
        make_selected(
          "/opt/conda/envs/myenv/bin/python",
          { name = "CONDA_PREFIX", val = "/opt/conda/envs/myenv" }
        ),
        false
      )
      assert.is_nil(vim.env.VIRTUAL_ENV)
      assert.are.equal("/opt/conda/envs/myenv", vim.env.CONDA_PREFIX)
    end)

    it("should clear both env vars when env_var has no name", function()
      vim.env.VIRTUAL_ENV = "/old"
      vim.env.CONDA_PREFIX = "/old"
      envs.handle_select(make_selected("/usr/bin/python3", {}), false)
      assert.is_nil(vim.env.VIRTUAL_ENV)
      assert.is_nil(vim.env.CONDA_PREFIX)
    end)

    it("should call after_handle_select callback", function()
      local called_with = nil
      require("whichpy.config").config.after_handle_select = function(selected)
        called_with = selected
      end
      local sel = make_selected("/usr/bin/python3")
      envs.handle_select(sel, false)
      assert.are.equal(sel, called_with)
    end)

    it("should write cache when should_cache is true", function()
      local cache = require("whichpy.cache")
      local save = stub(cache, "save")
      envs.handle_select(make_selected("/usr/bin/python3"), true)
      assert.spy(save).was.called(1)
      save:revert()
    end)

    it("should not write cache when should_cache is false", function()
      local cache = require("whichpy.cache")
      local save = stub(cache, "save")
      envs.handle_select(make_selected("/usr/bin/python3"), false)
      assert.spy(save).was.called(0)
      save:revert()
    end)
  end)

  describe("handle_select with update_path_env", function()
    it("should prepend to PATH on first select", function()
      require("whichpy.config").config.update_path_env = true
      local orig_path = vim.env.PATH
      envs.handle_select(make_selected("/home/.venv/bin/python", {}), false)
      assert.is_truthy(vim.env.PATH:find("/home/.venv/bin:", 1, true))
      vim.env.PATH = orig_path
    end)

    it("should replace previous path on subsequent select", function()
      require("whichpy.config").config.update_path_env = true
      local orig_path = vim.env.PATH
      envs.handle_select(make_selected("/first/bin/python", {}), false)
      envs.handle_select(make_selected("/second/bin/python", {}), false)
      assert.is_falsy(vim.env.PATH:find("/first/bin:", 1, true))
      assert.is_truthy(vim.env.PATH:find("/second/bin:", 1, true))
      vim.env.PATH = orig_path
    end)
  end)

  describe("handle_reset", function()
    it("should do nothing if no select was made", function()
      envs.handle_reset()
      assert.spy(handler1.restore_snapshot).was.called(0)
    end)

    it("should restore LSP snapshot", function()
      envs.handle_select(make_selected("/usr/bin/python3"), false)
      envs.handle_reset()
      assert.spy(handler1.restore_snapshot).was.called(1)
    end)

    it("should restore env vars to original values", function()
      vim.env.VIRTUAL_ENV = "/original/venv"
      vim.env.CONDA_PREFIX = nil

      -- Reload to capture original env vars in backup
      package.loaded["whichpy.envs"] = nil
      envs = require("whichpy.envs")

      envs.handle_select(
        make_selected("/new/bin/python", { name = "CONDA_PREFIX", val = "/new/conda" }),
        false
      )
      assert.are.equal("/new/conda", vim.env.CONDA_PREFIX)
      assert.is_nil(vim.env.VIRTUAL_ENV)

      envs.handle_reset()
      assert.are.equal("/original/venv", vim.env.VIRTUAL_ENV)
      assert.is_nil(vim.env.CONDA_PREFIX)
    end)

    it("should clear current_selected after reset", function()
      envs.handle_select(make_selected("/usr/bin/python3"), false)
      assert.is_not_nil(envs.current_selected())
      envs.handle_reset()
      assert.is_nil(envs.current_selected())
    end)

    it("should remove cache on reset", function()
      local cache = require("whichpy.cache")
      local remove = stub(cache, "remove")
      envs.handle_select(make_selected("/usr/bin/python3"), false)
      envs.handle_reset()
      assert.spy(remove).was.called(1)
      remove:revert()
    end)

    it("should restore PATH on reset when update_path_env is true", function()
      require("whichpy.config").config.update_path_env = true
      local orig_path = vim.env.PATH
      envs.handle_select(make_selected("/home/.venv/bin/python", {}), false)
      envs.handle_reset()
      assert.are.equal(orig_path, vim.env.PATH)
    end)
  end)

  describe("current_selected_name", function()
    it("should return env_var val after select", function()
      envs.handle_select(
        make_selected("/home/.venv/bin/python", { name = "VIRTUAL_ENV", val = "/home/.venv" }),
        false
      )
      assert.are.equal("/home/.venv", envs.current_selected_name())
    end)

    it("should return nil after reset", function()
      envs.handle_select(
        make_selected("/home/.venv/bin/python", { name = "VIRTUAL_ENV", val = "/home/.venv" }),
        false
      )
      envs.handle_reset()
      assert.is_nil(envs.current_selected_name())
    end)
  end)
end)
