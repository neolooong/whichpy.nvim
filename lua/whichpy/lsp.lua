local is_win = vim.uv.os_uname().sysname == "Windows_NT"
local bin_scripts = (is_win and "Scripts") or "bin"
local filename = (is_win and "python.exe") or "python"
local M = {
  pylsp = {},
  pyright = {},
}

---find the default python_path
---@param workspace string
---@return string
M.find_python_path = function(workspace)
  if vim.env.VIRTUAL_ENV then
    return vim.fs.joinpath(vim.env.VIRTUAL_ENV, bin_scripts, filename)
  end

  if workspace and vim.fn.filereadable(vim.fs.joinpath(workspace, "poetry.lock")) then
    local ok, res = pcall(function()
      return vim.system({ "poetry", "env", "info", "-p" }):wait()
    end)
    if ok and res.code == 0 then
      return vim.fs.joinpath(vim.trim(res.stdout), bin_scripts, filename)
    end
  end

  if workspace and vim.fn.filereadable(vim.fs.joinpath(workspace, "Pipfile")) then
    local ok, res = pcall(function()
      return vim
        .system(
          { "pipenv", "--venv" },
          { env = { PIPENV_PIPFILE = vim.fs.joinpath(workspace, "Pipfile") } }
        )
        :wait()
    end)
    if ok and res.code == 0 then
      return vim.fs.joinpath(vim.trim(res.stdout), bin_scripts, filename)
    end
  end

  local ok, res = pcall(function()
    return vim.system({ "pyenv", "which", "python" }):wait()
  end)
  if ok and res.code == 0 then
    return vim.trim(res.stdout)
  end

  return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
end

M.pylsp.python_path_getter = function(client)
  if
    client.settings.pylsp
    and client.settings.pylsp.plugins
    and client.settings.pylsp.plugins.jedi
  then
    return client.settings.pylsp.plugins.jedi.environment
  end
  return nil
end

M.pylsp.python_path_setter = function(client, python_path)
  if python_path then
    client.settings = vim.tbl_deep_extend("force", client.settings, {
      pylsp = {
        plugins = {
          jedi = {
            environment = python_path,
          },
        },
      },
    })
  else
    client.settings.pylsp.plugins.jedi.environment = nil
  end
  client.notify("workspace/didChangeConfiguration", { settings = client.settings })
end

M.pyright.python_path_getter = function(client)
  if client.settings.python then
    return client.settings.python.pythonPath
  end
  return nil
end

M.pyright.python_path_setter = function(client, python_path)
  if python_path then
    client.settings =
      vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = python_path } })
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  else
    vim.cmd(("LspRestart %s"):format(client.id))
  end
end

return M
