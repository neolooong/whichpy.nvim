local SearchJob = require("whichpy.search")
local config = require("whichpy.config").config
local handle_select = require("whichpy.envs").handle_select
local get_envs = require("whichpy.envs").get_envs

local Picker = {}

function Picker:setup()
  return vim.tbl_deep_extend(
    "force",
    {
      prompt = " ",
      title = "Select Python Interpreter",
      format = "text",
      layout = {
          hidden = { "preview" },
      }
    },
    config.picker["snacks"] or {}
  )
end

function Picker:show()
  local snacks_ok, snacks = pcall(require, "snacks")
  if not snacks_ok then
    vim.notify("snacks.nvim not found", vim.log.levels.ERROR)
    return
  end

  local opts = self:setup()
  local picker_instance = nil

  -- Start search if not already running
  if SearchJob:status() == nil then
    SearchJob:start()
  end

  -- Custom finder function that provides items and handles updates
  local function finder_fn(_picker_ctx)
    -- Get current environments
    local envs = (SearchJob:status() == "dead") and get_envs() or SearchJob._temp_envs

    -- Convert to snacks items format
    local items = {}
    for _, env in ipairs(envs) do
      table.insert(items, {
        text = tostring(env),
        env = env,
      })
    end

    return items
  end

  -- Create picker configuration with finder function
  local picker_opts = vim.tbl_deep_extend("force", opts, {
    finder = finder_fn,
    confirm = function(picker, item)
      picker:close()
      if item and item.env then
        handle_select(item.env)
      end
    end,
  })

  -- Show the picker
  picker_instance = snacks.picker.pick(picker_opts)

  -- If search is still running, hook into updates
  if SearchJob:status() ~= "dead" then
    SearchJob:update_hook(function(_)
      -- Refresh the picker with new results
      vim.schedule(function()
        if picker_instance and picker_instance.refresh then
          picker_instance:refresh()
        elseif picker_instance and picker_instance.find then
          picker_instance:find({ refresh = true })
        end
      end)
    end, nil)
  end
end

---@type WhichPy.Picker
return Picker
