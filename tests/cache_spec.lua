---@diagnostic disable: undefined-field, duplicate-set-field
local stub = require("luassert.stub")

describe("cache", function()
  local cache
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    package.loaded["whichpy.cache"] = nil
    cache = require("whichpy.cache")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
  end)

  describe("save and load", function()
    it("should round-trip interpreter path and locator name", function()
      cache.save(tmp_dir, "/usr/bin/python3", "global")
      local path, locator_name = cache.load(tmp_dir)
      assert.are.equal("/usr/bin/python3", path)
      assert.are.equal("global", locator_name)
    end)

    it("should return nil when no cache exists", function()
      local path, locator_name = cache.load(tmp_dir)
      assert.is_nil(path)
      assert.is_nil(locator_name)
    end)

    it("should overwrite previous cache", function()
      cache.save(tmp_dir, "/usr/bin/python3", "global")
      cache.save(tmp_dir, "/home/user/.venv/bin/python", "workspace")
      local path, locator_name = cache.load(tmp_dir)
      assert.are.equal("/home/user/.venv/bin/python", path)
      assert.are.equal("workspace", locator_name)
    end)

    it("should create cache_dir if it does not exist", function()
      local nested = vim.fs.joinpath(tmp_dir, "a", "b", "c")
      cache.save(nested, "/usr/bin/python3", "global")
      local path, locator_name = cache.load(nested)
      assert.are.equal("/usr/bin/python3", path)
      assert.are.equal("global", locator_name)
    end)
  end)

  describe("remove", function()
    it("should remove existing cache", function()
      cache.save(tmp_dir, "/usr/bin/python3", "global")
      cache.remove(tmp_dir)
      local path, locator_name = cache.load(tmp_dir)
      assert.is_nil(path)
      assert.is_nil(locator_name)
    end)

    it("should not error when no cache exists", function()
      assert.has_no.errors(function()
        cache.remove(tmp_dir)
      end)
    end)
  end)

  describe("save error handling", function()
    it("should notify on write failure", function()
      local notify = stub(require("whichpy.util"), "notify")
      local orig_open = io.open
      io.open = function(_, _)
        return nil, "mock error"
      end
      cache.save(tmp_dir, "/usr/bin/python3", "global")
      io.open = orig_open
      assert.spy(notify).was.called(1)
      assert
        .spy(notify).was
        .called_with("Failed to write cache: mock error", { level = vim.log.levels.WARN })
      notify:revert()
    end)
  end)
end)
