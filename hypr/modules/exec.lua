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

    for _, app in ipairs(s.autostart) do
        local cmd = app.command
        if app.workspace then
            cmd = "[workspace " .. app.workspace .. " silent] " .. cmd
        end
        hl.exec_cmd(cmd)
    end
end)
