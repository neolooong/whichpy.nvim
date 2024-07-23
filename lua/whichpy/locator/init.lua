return setmetatable({}, {
  __index = function(_, k)
    local ok, res = pcall(require, "whichpy.locator." .. k)
    if ok then
      return res
    else
      require("whichpy.util").notify_error(k .. " isn't a definded locator.")
      return nil
    end
  end,
})
