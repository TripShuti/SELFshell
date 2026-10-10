-- ============================================================
-- hyprland.lua — кореневий конфіг Hyprland (підключає модулі)
-- ============================================================
require("modules.env")
require("modules.general")
require("modules.exec")
require("modules.binds")
require("modules.animation")
require("modules.rules")

-- Персональні хуки живуть окремо від керованих модулів.
local localPath = os.getenv("HOME") .. "/.config/hypr/local.lua"
local localFile = io.open(localPath, "r")
if localFile then
    localFile:close()
    dofile(localPath)
end
