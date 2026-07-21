

hl.on("window.active", function(w)
    if w ~= nil then
        if w.class == "kitty" or w.class == "code-oss" or w.class == "bluetui" or w.class == "pulsemixer" then
            hl.exec_cmd("hyprctl switchxkblayout all 0")
        else
            hl.exec_cmd("hyprctl switchxkblayout all 1")
        end
    end
end)

hl.config({
  decoration = {
    blur = {
      popups = true,
      popups_ignorealpha = 0.6,
    }
  }
})

hl.window_rule({
    name      = "telegram-on-ws1",
    match     = { class = "^(org\\.telegram\\.desktop)$" },
    workspace = "1"
})

hl.window_rule({
    name      = "feishin-on-ws1",
    match     = { class = "^(feishin)$" },
    workspace = "1"
})

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

hl.window_rule({
    name = "bluetui-float",
    match = { class = "bluetui" },
    float = true,
    center = true,
    size = "750 400"
})

hl.window_rule({
    name = "pulsemixer-float",
    match = { class = "pulsemixer" },
    float = true,
    center = true,
    size = "750 400"
})


hl.window_rule({
    name   = "galculator-float",
    match  = { class = "galculator" },
    float  = true,
    center = true,
    size   = "400 540"
})

hl.window_rule({
    name   = "prismlauncher-float",
    match  = { class = "org.prismlauncher.PrismLauncher" },
    float  = true,
    center = true,
    size   = "701 487"
})

hl.window_rule({
    name   = "blender-file",
    match  = { class = "blender", title = "^(File Browser|Blender File View)$" },
    float  = true,
    center = true,
    size   = "982 577"
})

hl.window_rule({
    match   = { class = "blender" },
    opacity = "1.0 override 0.5 override 0.8 override",
})

hl.window_rule({
    match   = { class = "imv" },
    opacity = "1.0 override 0.5 override 0.8 override",
})