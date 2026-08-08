-- ============================================================
-- env.lua — змінні оточення з hypr/env.json (з дефолтами, якщо
-- файл відсутній або пошкоджений)
-- ============================================================
local json = require("modules.json")

local ENV_PATH = os.getenv("HOME") .. "/.config/hypr/env.json"

local env = json.read(ENV_PATH) or {}

local M = {}

M.mainMod      = env.mod or "SUPER"
M.terminal     = env.terminal or "kitty"
M.fileManager  = env.fileManager or "kitty -e yazi"
M.browser      = env.browser or "chromium"
M.cursorTheme  = env.cursorTheme or "Bibata-Modern-Classic"
M.cursorSize   = env.cursorSize or 24
M.kbLayout     = env.kbLayout or "us"
M.kbOptions    = env.kbOptions or ""
M.suspendKey   = env.suspendKey or ""
M.autostart    = env.autostart or {}
M.devices      = env.devices or {}
M.windowRules  = env.windowRules or {}
M.appLayout    = env.appLayout or {}
M.appLayoutActive = #M.appLayout > 0

return M
