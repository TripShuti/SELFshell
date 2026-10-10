-- ============================================================
-- env.lua — змінні оточення з hypr/env.json (з дефолтами, якщо
-- файл відсутній або пошкоджений)
-- ============================================================
local json = require("modules.json")

local ENV_PATH = os.getenv("HOME") .. "/.config/hypr/env.json"

local env = json.read(ENV_PATH)
if type(env) ~= "table" then env = {} end

-- Тип-перевірки: валідний JSON з неправильним типом поля не має
-- ламати конфіг — замість нього підставляється дефолт.
local function str(v, def) return type(v) == "string" and v or def end
local function num(v, def) return type(v) == "number" and v or def end
local function list(v, elementType)
    local result = {}
    if type(v) ~= "table" then return result end
    for _, entry in ipairs(v) do
        if type(entry) == elementType then result[#result + 1] = entry end
    end
    return result
end

local M = {}

M.mainMod      = str(env.mod, "SUPER")
M.terminal     = str(env.terminal, "kitty")
M.fileManager  = str(env.fileManager, "kitty -e yazi")
M.browser      = str(env.browser, "chromium")
M.cursorTheme  = str(env.cursorTheme, "breeze_cursors")
M.cursorSize   = num(env.cursorSize, 24)
M.kbLayout     = str(env.kbLayout, "us")
M.kbOptions    = str(env.kbOptions, "")
M.suspendKey   = str(env.suspendKey, "")
M.autostart    = {}
for _, app in ipairs(list(env.autostart, "table")) do
    if type(app.command) == "string" and app.command ~= "" and
       (app.workspace == nil or type(app.workspace) == "string" or type(app.workspace) == "number") then
        M.autostart[#M.autostart + 1] = app
    end
end
M.devices      = list(env.devices, "table")
M.windowRules  = list(env.windowRules, "table")

return M
