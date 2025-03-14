local M = require("lualine.component"):extend()

function M:init(options)
    M.super.init(self, options)
end

function M:update_status()
    if vim.bo.filetype == "python" then
        local icon = ""
        local ok, plenary, devicons

        ok, devicons = pcall(require, "nvim-web-devicons")
        if ok then
            icon, _ = devicons.get_icon(vim.fn.expand("%:t"))
        end

        local venv = require("whichpy.envs").current_selected_name()
        if not venv then
            return nil
        end

        ok, plenary = pcall(require, "plenary")
        if ok then
            venv = plenary.path:new(venv):shorten()
        end

        return icon .. venv
    end
    return nil
end

return M
