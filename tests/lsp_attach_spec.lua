---@diagnostic disable: undefined-field
local match = require("luassert.match")
local mock = require("luassert.mock")
local stub = require("luassert.stub")

local function new_fake_handler()
  local fake_handler = { _call_order = {} }

  function fake_handler:snapshot_settings(_)
    table.insert(self._call_order, "snapshot_settings")
  end

  function fake_handler:restore_snapshot(_)
    table.insert(self._call_order, "restore_snapshot")
  end

  function fake_handler:set_python_path(_, _)
    table.insert(self._call_order, "set_python_path")
  end

  return fake_handler
end

describe("LSP attach behavior", function()
  local lsp_handler1, lsp_handler2
  local fake_client1 = { name = "srv1", id = 1 }
  local fake_client2 = { name = "srv2", id = 2 }

  before_each(function()
    lsp_handler1 = mock(new_fake_handler())
    lsp_handler2 = mock(new_fake_handler())
    require("whichpy").setup({
      lsp = {
        srv1 = lsp_handler1,
        srv2 = lsp_handler2,
      },
    })

    stub(vim.lsp, "get_client_by_id", function(id)
      if id == 1 or id == 3 then
        return fake_client1
      elseif id == 2 or id == 4 then
        return fake_client2
      end
    end)
  end)

  after_each(function()
    mock.revert(lsp_handler1)
    mock.revert(lsp_handler2)
    vim.lsp.get_client_by_id:revert()
    require("whichpy.lsp")._clients = {}
  end)

  local function trigger_lsp_attach(client_id)
    require("whichpy.lsp").lsp_attach_callback({ data = { client_id = client_id } })
  end

  describe("with single LSP server", function()
    it("should load cache when no interpreter is selected", function()
      local current_selected = stub(require("whichpy.envs"), "current_selected")
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      assert.are.same(1, require("whichpy.lsp")._clients["srv1"])
      assert.spy(retrieve_cache).was.called(1)
      assert.spy(lsp_handler1.snapshot_settings).was.called(0)
      assert.spy(lsp_handler1.set_python_path).was.called(0)
      current_selected:revert()
      retrieve_cache:revert()
    end)

    it("should configure LSP with cached interpreter path", function()
      local current_selected = stub(require("whichpy.envs"), "current_selected", "/path/to/python")
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      assert.spy(retrieve_cache).was.called(0)
      assert.spy(lsp_handler1.snapshot_settings).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called_with(match._, match._, "/path/to/python")
      current_selected:revert()
      retrieve_cache:revert()
    end)

    it("should load cache only once for multiple buffer attaches", function()
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      assert.spy(retrieve_cache).was.called(1)
      trigger_lsp_attach(1)
      assert.spy(retrieve_cache).was.called(1)
      trigger_lsp_attach(1)
      assert.spy(retrieve_cache).was.called(1)
      retrieve_cache:revert()
    end)

    it("should reuse LSP settings for subsequent buffer attaches", function()
      local current_selected = stub(require("whichpy.envs"), "current_selected", "/path/to/python")
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      assert.spy(retrieve_cache).was.called(0)
      assert.spy(lsp_handler1.snapshot_settings).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called(1)
      trigger_lsp_attach(1)
      trigger_lsp_attach(1)
      assert.spy(retrieve_cache).was.called(0)
      assert.spy(lsp_handler1.snapshot_settings).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called(1)
      assert.are.same({ "snapshot_settings", "set_python_path" }, lsp_handler1._call_order)
      current_selected:revert()
      retrieve_cache:revert()
    end)

    it("should reconfigure LSP settings after server restart", function()
      local current_selected = stub(require("whichpy.envs"), "current_selected", "/path/to/python")
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      trigger_lsp_attach(3)
      assert.spy(retrieve_cache).was.called(0)
      assert.spy(lsp_handler1.snapshot_settings).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called(2)
      assert.are.same(
        { "snapshot_settings", "set_python_path", "set_python_path" },
        lsp_handler1._call_order
      )
      current_selected:revert()
      retrieve_cache:revert()
    end)
  end)

  describe("with multiple LSP servers", function()
    it("should configure multiple LSP servers with the same interpreter path", function()
      local current_selected = stub(require("whichpy.envs"), "current_selected", "/path/to/python")
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      trigger_lsp_attach(2)
      assert.spy(retrieve_cache).was.called(0)
      assert.spy(lsp_handler1.snapshot_settings).was.called(1)
      assert.spy(lsp_handler2.snapshot_settings).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called(1)
      assert.spy(lsp_handler2.set_python_path).was.called(1)
      assert.are.same({ "snapshot_settings", "set_python_path" }, lsp_handler1._call_order)
      assert.are.same({ "snapshot_settings", "set_python_path" }, lsp_handler2._call_order)
      current_selected:revert()
      retrieve_cache:revert()
    end)

    it("should reconfigure multiple LSP servers after restart", function()
      local current_selected = stub(require("whichpy.envs"), "current_selected", "/path/to/python")
      local retrieve_cache = stub(require("whichpy.envs"), "retrieve_cache")
      trigger_lsp_attach(1)
      trigger_lsp_attach(2)
      trigger_lsp_attach(3)
      trigger_lsp_attach(4)

      assert.spy(retrieve_cache).was.called(0)
      assert.spy(lsp_handler1.snapshot_settings).was.called(1)
      assert.spy(lsp_handler2.snapshot_settings).was.called(1)
      assert.spy(lsp_handler1.set_python_path).was.called(2)
      assert.spy(lsp_handler2.set_python_path).was.called(2)
      assert.are.same(
        { "snapshot_settings", "set_python_path", "set_python_path" },
        lsp_handler1._call_order
      )
      assert.are.same(
        { "snapshot_settings", "set_python_path", "set_python_path" },
        lsp_handler2._call_order
      )
      current_selected:revert()
      retrieve_cache:revert()
    end)
  end)
end)
