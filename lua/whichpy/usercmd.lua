local util = require("whichpy.util")

local M = {}

local subcommand_tbl = {
  select = {
    impl = function(opts)
      if #opts.fargs == 1 then
        require("whichpy.envs").show_selector()
      elseif #opts.fargs > 2 then
        vim.notify("Too many arguments", vim.log.levels.ERROR)
      else
        local python_path = opts.fargs[2]
        if not vim.uv.fs_stat(python_path) then
          util.notify(python_path .. " doesn't exists.")
        else
          require("whichpy.envs").handle_select(require("whichpy.locator.global"), python_path)
        end
      end
    end,
    complete = function(subcmd_arg_lead)
      local envs = require("whichpy.envs").get_envs()
      if #envs == 0 then
        return {}
      end
      envs = vim
        .iter(envs)
        :map(function(env)
          return env.interpreter_path
        end)
        :filter(function(env)
          return env:find(subcmd_arg_lead)
        end)
        :totable()
      return util.deduplicate(envs)
    end,
  },
  restore = {
    impl = function(opts)
      if #opts.fargs > 1 then
        vim.notify("Too many arguments", vim.log.levels.ERROR)
      else
        require("whichpy.envs").handle_restore()
      end
    end,
  },
  retrieve = {
    impl = function(opts)
      if #opts.fargs > 1 then
        vim.notify("Too many arguments", vim.log.levels.ERROR)
      else
        require("whichpy.envs").retrieve_cache()
      end
    end,
  },
  rescan = {
    impl = function(opts)
      if #opts.fargs > 1 then
        vim.notify("Too many arguments", vim.log.levels.ERROR)
      else
        require("whichpy.envs").asearch()
      end
    end,
  },
}

local function main_cmd(opts)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]

  local subcommand = subcommand_tbl[subcommand_key]
  if not subcommand then
    vim.notify("WhichPy: Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
  end

  subcommand.impl(opts)
end

M.create_user_cmd = function()
  vim.api.nvim_create_user_command("WhichPy", main_cmd, {
    nargs = "+",
    complete = function(arg_lead, cmdline, _)
      local subcmd_key, subcmd_arg_lead = cmdline:match("^WhichPy%s+(%S+)%s+(.*)$")
      if
        subcmd_key
        and subcmd_arg_lead
        and subcommand_tbl[subcmd_key]
        and subcommand_tbl[subcmd_key].complete
      then
        return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
      end

      if cmdline:match("^WhichPy%s+%w*$") then
        local subcommand_keys = vim.tbl_keys(subcommand_tbl)
        return vim
          .iter(subcommand_keys)
          :filter(function(key)
            return key:find(arg_lead) ~= nil
          end)
          :totable()
      end
    end,
  })
end

return M
