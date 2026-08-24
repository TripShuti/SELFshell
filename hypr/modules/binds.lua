-- ============================================================
-- binds.lua — гарячі клавіші
-- ============================================================
local s = require("modules.env")
local json = require("modules.json")

-- Користувацькі оверрайди: ~/.config/hypr/binds.json (пише
-- Settings → Binds у шеллі). Формат значень — повний рядок бінду
-- Hyprland, напр. "SUPER + SHIFT + V"; suspend — одиночна клавіша.
-- Немає файлу/ключа — діє дефолт нижче.
local overrides = json.read(os.getenv("HOME") .. "/.config/hypr/binds.json") or {}
local function bindKey(name, default)
    local v = overrides[name]
    if type(v) == "string" and v ~= "" then return v end
    return default
end

-- Скріншоти: Print — весь екран, SUPER+Print — виділення (slurp).
-- Шлях збереженого файлу пишеться в маркер-файл data/last-shot.txt —
-- той самий, що читає ControlPopup для тоста (єдиний спосіб тоста й
-- для бінда, і для кнопок попапа)
local shotMarkerFile = "~/.config/quickshell/data/last-shot.txt"

local function makeShotCmd(region)
    local capture = region and 'grim -g "$(slurp)" - ' or "grim - "
    return "sh -c 'f=~/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; " .. capture ..
           "| tee \"$f\" | wl-copy; if [ -s \"$f\" ]; then echo \"$f\" > " ..
           shotMarkerFile .. "; fi'"
end

hl.bind("Print", hl.dsp.exec_cmd(makeShotCmd(false)))
hl.bind("SUPER + Print", hl.dsp.exec_cmd(makeShotCmd(true)))

-- Медіаклавіші: гучність (wpctl) та яскравість (ddcutil) з OSD-індикатором.
-- OSD показується через IPC після зміни значення.
-- ddcutil глушиться 2>/dev/null: на моніторах без DDC команда падає, але
-- OSD має все одно показатися.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("sh -c 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && qs ipc call osd volume'"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("sh -c 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && qs ipc call osd volume'"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("sh -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; qs ipc call osd volume'"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh -c 'ddcutil setvcp 10 + 5 2>/dev/null; qs ipc call osd brightness'"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'ddcutil setvcp 10 - 5 2>/dev/null; qs ipc call osd brightness'"))

-- Керування шеллом — переназначаються у Settings → Binds
hl.bind(bindKey("launcher", s.mainMod .. " + R"), hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(bindKey("settings", s.mainMod .. " + S"), hl.dsp.exec_cmd("qs ipc call settings toggle"))
hl.bind(bindKey("control",  s.mainMod .. " + Escape"), hl.dsp.exec_cmd("qs ipc call control toggle"))
hl.bind(bindKey("lock",     s.mainMod .. " + L"), hl.dsp.exec_cmd("qs ipc call lockscreen toggle"))
hl.bind(bindKey("clipboard", s.mainMod .. " + SHIFT + V"), hl.dsp.exec_cmd("qs ipc call clipboard toggle"))

-- Додатки
hl.bind(bindKey("browser", s.mainMod .. " + W"), hl.dsp.exec_cmd(s.browser))
hl.bind(bindKey("terminal", s.mainMod .. " + Q"), hl.dsp.exec_cmd(s.terminal))
hl.bind(bindKey("files", s.mainMod .. " + E"), hl.dsp.exec_cmd(s.fileManager))

-- Клавіша сну: дефолт — suspendKey з env.json (може бути порожнім),
-- оверрайд у binds.json має пріоритет
local suspend = bindKey("suspend", s.suspendKey)
if suspend ~= "" then
    hl.bind(suspend, hl.dsp.exec_cmd("systemctl suspend"))
end
-- SUPER+Escape — центр керування (живлення/налаштування) — див. control вище

hl.bind(s.mainMod .. " + C", hl.dsp.window.close())
hl.bind(s.mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

hl.bind(s.mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(s.mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(s.mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(s.mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(s.mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(s.mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(s.mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(s.mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(s.mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(s.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
