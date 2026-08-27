-- ============================================================
-- rules.lua — правила для вікон: розкладка, float, opacity
-- ============================================================
local s = require("modules.env")
local json = require("modules.json")
local V = json.read(os.getenv("HOME") .. "/.config/hypr/visual.json") or {}
local function num(v, def) return type(v) == "number" and v or def end
local function bool(v, def) if type(v) == "boolean" then return v end return def end

hl.layer_rule({
    name = "blur-bar",
    match = { namespace = "^quickshell$" },
    blur = true,
    ignore_alpha = num(V.layer_ignore_alpha, 0),
    xray = bool(V.layer_xray, true),
})
hl.layer_rule({
    name = "blur-popups",
    match = { namespace = "^quickshell$" },
    blur_popups = true,
    ignore_alpha = num(V.layer_popups_ignore_alpha, 0.05),
    xray = bool(V.layer_xray, true),
})
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