-- ============================================================
-- exec.lua — автозапуск програм при старті Hyprland.
-- Користувацькі автостарти — у hypr/env.json (autostart)
-- ============================================================
local s = require("modules.env")

hl.env("XCURSOR_SIZE", s.cursorSize)
hl.env("HYPRCURSOR_SIZE", s.cursorSize)
if s.cursorTheme ~= "" then
    hl.env("XCURSOR_THEME", s.cursorTheme)
end

hl.on("hyprland.start", function()
    if s.cursorTheme ~= "" then
        hl.exec_cmd("hyprctl setcursor " .. s.cursorTheme .. " " .. s.cursorSize)
    end

    -- Сам шелл — інфраструктура, запускається завжди
    hl.exec_cmd("sleep 2 && quickshell")

    -- Polkit-агент: діалоги підвищення прав для GUI (Pamac, системні дії).
    -- Трохи пізніше за шелл, щоб сесійна D-Bus шина була готова.
    hl.exec_cmd("sleep 3 && lxqt-policykit-agent")

    -- Історія буфера обміну (cliphist): wl-paste --watch перехоплює зміни
    -- буфера (текст та зображення) і зберігає їх для ClipboardPopup
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image/png --watch cliphist store")

    for _, app in ipairs(s.autostart) do
        local cmd = app.command
        if app.workspace then
            cmd = "[workspace " .. app.workspace .. " silent] " .. cmd
        end
        hl.exec_cmd(cmd)
    end
end)
