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

-- Прогрів: гасимо екран при першому моніторі, щоб під час старту
-- не миготів робочий стіл. Вмикається знову після локу (нижче).
local firstMonitorAdded = true
hl.on("monitor.added", function(mon)
    if firstMonitorAdded then
        firstMonitorAdded = false
        hl.dispatch(hl.dsp.dpms({ action = "disable", monitor = mon.name }))
    end
end)

hl.on("hyprland.start", function()
    if s.cursorTheme ~= "" then
        hl.exec_cmd("hyprctl setcursor " .. s.cursorTheme .. " " .. s.cursorSize)
    end

    -- Сам шелл — інфраструктура, запускається завжди
    hl.exec_cmd("sleep 2 && quickshell")

    -- Лок при старті сесії: екран лишається вимкненим, поки лок не
    -- показаний (dpms on після успішного локу). Ретраї — шелл
    -- піднімається ~2-3 с, qs ipc ще може не відповідати
    hl.exec_cmd("sh -c 'sleep 3 && for i in 1 2 3 4 5; do qs ipc call lockscreen lock && break; sleep 0.2; done && hyprctl dispatch dpms on'")

    for _, app in ipairs(s.autostart) do
        local cmd = app.command
        if app.workspace then
            cmd = "[workspace " .. app.workspace .. " silent] " .. cmd
        end
        hl.exec_cmd(cmd)
    end
end)
