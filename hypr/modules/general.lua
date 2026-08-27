-- ============================================================
-- general.lua — налаштування вікон, декору, введення.
-- Візуальні параметри зчитуються з ~/.config/hypr/visual.json
-- (пише Settings → Hyprland → Windows/Blur); ключа немає — діє
-- дефолт нижче. Дефолти мають збігатися з hyprDefaults у
-- HyprlandSection.qml.
-- ============================================================
local s = require("modules.env")
local json = require("modules.json")

local V = json.read(os.getenv("HOME") .. "/.config/hypr/visual.json") or {}

local function num(v, def)  return type(v) == "number"  and v or def end
-- УВАГА: не `v and v or def` — для false той вираз повертає def
local function bool(v, def)
    if type(v) == "boolean" then return v end
    return def
end
-- Рядок (колір "rgba(...)", назва лейаута, орієнтація) або "" / не-рядок → дефолт
local function str(v, def)  return type(v) == "string" and v ~= "" and v or def end

hl.config({
    general = {
        gaps_in  = num(V.gaps_in, 3),
        gaps_out = num(V.gaps_out, 6),
        border_size = num(V.border_size, 0),
        col = {
            -- Колір користувача замінює дефолтний градієнт суцільним
            active_border   = str(V.active_border, { colors = {"rgba(3a452aaa)", "rgba(4b543eaa)"}, angle = 45 }),
            inactive_border = str(V.inactive_border, "rgba(111a1294)"),
        },
        resize_on_border = bool(V.resize_on_border, false),
        allow_tearing    = false,
        layout           = str(V.layout, "master"),
    },
    master = {
        mfact       = num(V.mfact, 0.7),
        orientation = str(V.orientation, "left"),
        new_status  = str(V.new_status, "slave"), -- "master" "inherit" "slave"
        always_keep_position = bool(V.always_keep_position, false),
        allow_small_split = false,
        special_scale_factor = 1,
        new_on_top = true,
        new_on_active = "none", --"after" "before" "none"
        slave_count_for_center_master = 2,
        center_master_fallback = "left", -- "left", "right", "top", "bottom"
        smart_resizing = true,
        drop_at_cursor = true,
        focus_master_on_close = true
    },
    dwindle = {
        force_split                  = 0,
        preserve_split               = false,
        smart_split                  = false,
        smart_resizing               = true,
        permanent_direction_override = false,
        special_scale_factor         = 1,
        split_width_multiplier       = 1.0,
        use_active_for_splits        = true,
        default_split_ratio          = 1.0,
        split_bias                   = 0,
        precise_mouse_move           = false,
    },

    cursor = {
        no_warps = true,
        inactive_timeout = num(V.inactive_timeout, 3),
    },

    misc = {
        focus_on_activate = true,
    },

    decoration = {
        rounding        = num(V.rounding, 10),
        rounding_power  = num(V.rounding_power, 2.0),
        dim_inactive    = bool(V.dim_inactive, true),
        dim_strength    = num(V.dim_strength, 0.3),
        active_opacity   = num(V.active_opacity, 0.95),
        inactive_opacity = num(V.inactive_opacity, 0.9),
        blur = {
            enabled = bool(V.blur_enabled, true),
            popups = bool(V.blur_popups, true),
            popups_ignorealpha = num(V.blur_popups_ignorealpha, 0.1),
            ignore_opacity = bool(V.blur_ignore_opacity, false),
            xray = bool(V.blur_xray, false),
            new_optimizations = bool(V.blur_new_optimizations, true),

            vibrancy = num(V.blur_vibrancy, 0.4),
            vibrancy_darkness = num(V.blur_vibrancy_darkness, 0.3),
            passes = num(V.blur_passes, 2),
            size = num(V.blur_size, 4),
            noise = num(V.blur_noise, 0.02),
            contrast = num(V.blur_contrast, 1.05),
            brightness = num(V.blur_brightness, 1.0),
        },
         shadow = {
        enabled = bool(V.shadows, false),
        range = 2,
        render_power = 3,
        sharp = true,
        color = 0xee1a1a1a,
        offset = {0, 0},
        scale = 1.0
        },

    },

    input = {
        kb_layout  = s.kbLayout,
        kb_options = s.kbOptions,
        follow_mouse = 1,
    },
})

-- Налаштування конкретних пристроїв — з hypr/env.json (devices).
-- Для неіснуючого пристрою запис неактивний (не ламає нічого).
for _, dev in ipairs(s.devices) do
    hl.device({
        name          = dev.name,
        sensitivity   = dev.sensitivity,
        accel_profile = dev.accel_profile,
        scroll_factor = dev.scroll_factor,
    })
end
