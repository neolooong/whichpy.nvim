local config = require("whichpy.config").config
local SearchJob = require("whichpy.search")
local final_envs = {}
local orig_interpreter_path
local curr_interpreter_path

local M = {}

M.asearch = function()
  SearchJob:start()
end

M.set_envs = function(envs)
  final_envs = envs
end

M.get_envs = function()
  if SearchJob:status() == "dead" then
    return final_envs
  end
  return SearchJob:_temp_envs()
end

-- TODO: Improve readability by moving the picker into its own function?
M.show_selector = function()
  if config.picker == "fzf-lua" and require("whichpy.util").is_support("fzf-lua") then
    local fzf_contents = function(fzf_cb)
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
        for _, env in ipairs(final_envs) do
          fzf_cb(env)
        end
      end
    end

    if SearchJob:status() == nil then
      SearchJob:start()
    end

    require("fzf-lua").fzf_exec(fzf_contents, {
      fzf_opts = { ["--layout"] = "reverse" },
      actions = {
        ["default"] = function(selected, _)
          local _, _interpreter_path = string.gmatch(selected[1], "%(([%w ]+)%) (.+)")()
          M.handle_select(_interpreter_path)
        end,
        ["ctrl-r"] = {
          function(_)
            SearchJob:start()
          end,
          require("fzf-lua").actions.resume,
        },
      },
    })
    return
  end

  if config.picker == "telescope" and require("whichpy.util").is_support("fzf-lua") then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

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
    picker = pickers.new(require("telescope.themes").get_dropdown({}), {
      prompt = "Select Python Interpreter",
      finder = finders.new_table({}),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(_, map)
        map({ "i", "n" }, "<Cr>", function(prompt_bufnr)
          actions.close(prompt_bufnr)
          local selected_entry = action_state.get_selected_entry()
          M.handle_select(selected_entry.value.interpreter_path)
        end)

        map({ "i", "n" }, "<C-r>", function()
          SearchJob:start()
          picker:refresh(new_finder(SearchJob._temp_envs))
          SearchJob:update_hook(function(_)
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
      picker.finder = new_finder(final_envs)
    end
    picker:find()
    return
  end

  local function show_ui()
    vim.ui.select(final_envs, { prompt = "Select Python Interpreter" }, function(choice)
      if choice ~= nil then
        M.handle_select(choice.interpreter_path)
      end
    end)
  end
  if SearchJob:status() == nil then
    SearchJob:update_hook(nil, show_ui)
    SearchJob:start()
  elseif SearchJob:status() ~= "dead" then
    SearchJob:update_hook(nil, show_ui)
  else
    show_ui()
  end
end

M.handle_select = function(interpreter_path, should_cache)
  local selected = orig_interpreter_path ~= nil
  local _orig_interpreter_path = {}
  should_cache = should_cache == nil or should_cache

  if not selected then
    _orig_interpreter_path["lsp"] = {}
  end

  -- lsp
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      if not selected then
        _orig_interpreter_path["lsp"][lsp_name] = handler.get_python_path(client)
      end
      handler.set_python_path(client, interpreter_path)
    end
  end

  -- cache
  if should_cache then
    vim.fn.mkdir(config.cache_dir, "p")
    local filename = vim.fn.getcwd():gsub("[\\/:]+", "%%")
    local f = assert(io.open(vim.fs.joinpath(config.cache_dir, filename), "wb"))
    f:write(interpreter_path)
    f:close()
  end

  if not selected then
    orig_interpreter_path = _orig_interpreter_path
  end
  curr_interpreter_path = interpreter_path
end

M.handle_restore = function()
  if orig_interpreter_path == nil then
    return
  end

  -- lsp
  for lsp_name, handler in pairs(config.lsp) do
    local client = vim.lsp.get_clients({ name = lsp_name })[1]
    if client then
      handler.set_python_path(client, orig_interpreter_path.lsp[client])
    end
  end

  -- cache
  local filename = vim.fn.getcwd():gsub("/", "%%")
  os.remove(vim.fs.joinpath(config.cache_dir, filename))

  orig_interpreter_path = nil
  curr_interpreter_path = nil
end

M.retrieve_cache = function()
  local filename = vim.fn.getcwd():gsub("/", "%%")
  local f = io.open(vim.fs.joinpath(config.cache_dir, filename), "r")
  if not f then
    require("whichpy.util").notify_info("No cache.")
    return
  end
  local interpreter_path = f:read()
  f:close()

  M.handle_select(interpreter_path, false)
end

M.current_selected = function()
  return curr_interpreter_path
end

return M
