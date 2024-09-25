local M = {}

function M.run(func, callback, ...)
  local co = coroutine.create(func)
  local function step(...)
    local ret = { coroutine.resume(co, ...) }
    local stat = ret[1]

    if not stat then
      local err = ret[2]
      error(
        string.format("The coroutine failed with this message: %s\n%s", err, debug.traceback(co))
      )
    end

    if coroutine.status(co) == "dead" then
      if callback then
        callback(unpack(ret, 2, table.maxn(ret)))
      end
      return
    end

    local fn = ret[2]
    local opts = { unpack(ret, 3, table.maxn(ret)) }
    ---@diagnostic disable-next-line: assign-type-mismatch
    opts[table.maxn(opts) + 1] = step
    fn(unpack(opts))
  end

  step(...)
end

function M.wrap(func)
  local pfunc = function(...)
    local args = { ... }
    local cb_idx = table.maxn(args)
    local cb = args[cb_idx]
    args[cb_idx] = function(...)
      if vim.in_fast_event() then
        args = {...}
        vim.schedule(function ()
          cb(true, unpack(args))
        end)
      else
        cb(true, ...)
      end
    end
    xpcall(func, function(err)
      -- nested xpcall causes coroutine hangs if another error is thrown inside the error handler.
      vim.schedule(function()
        cb(false, err, debug.traceback())
      end)
    end, unpack(args))
  end

  return function(...)
    return coroutine.yield(pfunc, ...)
  end
end

M.asystem = M.wrap(vim.system)

return M
