-- ============================================================
-- rules.lua — правила для вікон: розкладка, float, opacity
-- ============================================================
local s = require("modules.env")

-- Автоматичне перемикання розкладки за класом вікна — опційна фіча:
-- вмикається лише якщо в env.json задано `appLayout` (список
-- {class, layout}) І кількість розкладок у `kbLayout` більша за одну
-- (switchxkblayout індексує розкладку за порядком у списку, тому для
-- однієї розкладки фіча не має сенсу).
if s.appLayoutActive and string.find(s.kbLayout, ",") ~= nil then
    local lastLayout = -1
    hl.on("window.active", function(w)
        if w ~= nil then
            local target = 0
            for _, entry in ipairs(s.appLayout) do
                if w.class == entry.class then
                    target = entry.layout
                    break
                end
            end
            if target ~= lastLayout then
                hl.exec_cmd("hyprctl switchxkblayout all " .. tostring(target))
                lastLayout = target
            end
        end
    end)
end

-- Універсальні правила, які не залежать від набору програм користувача.
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize"
})

hl.window_rule({
    name     = "fix-xwayland-drags",
    match    = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true
})

-- Правила для конкретних програм — з hypr/env.json (windowRules).
for _, rule in ipairs(s.windowRules) do
    hl.window_rule(rule)
end