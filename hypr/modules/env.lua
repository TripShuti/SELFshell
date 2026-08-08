-- ============================================================
-- env.lua — змінні оточення з hypr/env.json (з дефолтами, якщо
-- файл відсутній або пошкоджений)
-- ============================================================
local json = require("modules.json")

local ENV_PATH = os.getenv("HOME") .. "/.config/hypr/env.json"

local env = json.read(ENV_PATH) or {}

local M = {}

M.mainMod     = env.mod or "SUPER"
M.terminal    = env.terminal or "kitty"
M.fileManager = env.fileManager or "kitty -e yazi"
M.browser     = env.browser or "chromium"
M.cursorTheme = env.cursorTheme or "capitaine-cursors"
M.cursorSize  = env.cursorSize or 24
M.autostart   = env.autostart or {}
M.devices     = env.devices or {}

return M
