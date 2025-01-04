local SearchJob = require("whichpy.search")
local config = require("whichpy.config").config
local handle_select = require("whichpy.envs").handle_select
local get_envs = require("whichpy.envs").get_envs

local Picker = {
  env_map = {},
}

function Picker:setup()
  return vim.tbl_deep_extend(
    "force",
    {
      fzf_opts = { ["--layout"] = "reverse" },
      winopts = { height = 0.33, width = 0.66 },
    },
    config.picker["fzf-lua"] or {},
    { fzf_opts = { ["--with-nth"] = "2", ["--delimiter"] = "\t" } },
    {
      actions = {
        ["default"] = function(selected, _)
          local key = string.match(selected[1], "^(.*)\t")
          local env = Picker.env_map[key]
          handle_select(env.locator, env.interpreter_path)
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
  local key = 1
  Picker.env_map = {}

  local _cb = function(env_info)
    if env_info then
      Picker.env_map[tostring(key)] = env_info
      fzf_cb(key .. "\t" .. tostring(env_info))
      key = key + 1
    else
      fzf_cb()
    end
  end

  if SearchJob:status() ~= "dead" then
    SearchJob:update_hook(_cb, _cb)
    for _, env in ipairs(SearchJob._temp_envs) do
      Picker.env_map[tostring(key)] = env
      fzf_cb(key .. "\t" .. tostring(env))
      key = key + 1
    end
  else
    for _, env in ipairs(get_envs()) do
      Picker.env_map[tostring(key)] = env
      fzf_cb(key .. "\t" .. tostring(env))
      key = key + 1
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

---@type WhichPy.Picker
return Picker
