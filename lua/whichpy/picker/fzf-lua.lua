local SearchJob = require("whichpy.search")
local config = require("whichpy.config").config
local handle_select = require("whichpy.envs").handle_select
local get_envs = require("whichpy.envs").get_envs

local Picker = {}

function Picker:setup()
  return vim.tbl_deep_extend(
    "force",
    {
      fzf_opts = { ["--layout"] = "reverse" },
      winopts = { height = 0.33, width = 0.66 },
    },
    config.picker["fzf-lua"] or {},
    {
      actions = {
        ["default"] = function(selected, _)
          local _, _interpreter_path = string.gmatch(selected[1], "%(([%w ]+)%) (.+)")()
          handle_select(_interpreter_path)
        end,
        ["ctrl-r"] = {
          function(_)
            SearchJob:start()
          end,
          require("fzf-lua").actions.resume,
        },
      },
    }
  )
end

Picker._fzf_contents = function(fzf_cb)
  local _cb = function(env_info)
    if env_info then
      fzf_cb(env_info)
    else
      fzf_cb()
    end
  end

  if SearchJob:status() ~= "dead" then
    SearchJob:update_hook(_cb, _cb)
    for _, env in ipairs(SearchJob._temp_envs) do
      fzf_cb(env)
    end
  else
    for _, env in ipairs(get_envs()) do
      fzf_cb(env)
    end
    fzf_cb()
  end
end

function Picker:show()
  local opts = self:setup()

  if SearchJob:status() == nil then
    SearchJob:start()
  end

  require("fzf-lua").fzf_exec(self._fzf_contents, opts)
end

return Picker
