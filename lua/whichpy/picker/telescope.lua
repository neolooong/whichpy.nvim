local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local SearchJob = require("whichpy.search")
local config = require("whichpy.config").config
local handle_select = require("whichpy.envs").handle_select
local get_envs = require("whichpy.envs").get_envs

local Picker = {}

function Picker:setup()
  return vim.tbl_deep_extend(
    "force",
    require("telescope.themes").get_dropdown({}),
    config.picker["telescope"] or {}
  )
end

function Picker:show()
  local opts = self:setup()

  local new_finder = function(envs)
    return finders.new_table({
      results = envs,
      entry_maker = function(entry)
        return {
          value = entry,
          display = tostring(entry),
          ordinal = tostring(entry),
        }
      end,
    })
  end

  local picker
  picker = pickers.new(opts, {
    prompt_title = "Select Python Interpreter",
    finder = finders.new_table({}),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map)
      map({ "i", "n" }, "<Cr>", function(prompt_bufnr)
        actions.close(prompt_bufnr)
        local selected_entry = action_state.get_selected_entry()
        handle_select(selected_entry.value.interpreter_path)
      end)

      map({ "i", "n" }, "<C-r>", function()
        SearchJob:start()
        picker:refresh(new_finder(SearchJob._temp_envs))
        SearchJob:update_hook(function()
          picker:refresh(new_finder(SearchJob._temp_envs))
        end)
      end)
      return true
    end,
  })

  if SearchJob:status() == nil then
    SearchJob:start()
  end

  if SearchJob:status() ~= "dead" then
    picker.finder = new_finder(SearchJob._temp_envs)
    SearchJob:update_hook(function(_)
      picker:refresh(new_finder(SearchJob._temp_envs))
    end)
  else
    picker.finder = new_finder(get_envs())
  end
  picker:find()
end

return Picker
