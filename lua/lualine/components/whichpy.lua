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

        local whichpy_python = require("whichpy.envs").current_selected()
        if not whichpy_python then
            return nil
        end
        local venv = vim.fs.dirname(vim.fs.dirname(whichpy_python))

        ok, plenary = pcall(require, "plenary")
        if ok then
            venv = plenary.path:new(venv):shorten()
        end

        return icon .. venv
    end
    return nil
end

return M
