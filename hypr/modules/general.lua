-- ============================================================
-- general.lua — налаштування вікон, декору, введення
-- ============================================================
local s = require("modules.env")

hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 1,
        border_size = 1,
        col = {
            active_border   = { colors = {"rgba(3a452aaa)", "rgba(4b543eaa)"}, angle = 45 },
            inactive_border = "rgba(111a1294)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
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
    },

    misc = {
        focus_on_activate = true,
    },

    decoration = {
        blur = {
            enabled = true,
            popups = true,
            popups_ignorealpha = 0.6,

            vibrancy = 0.35,
            vibrancy_darkness = 0.2,
            passes = 3,
            size = 6,
            noise = 0.02,
            contrast = 1.05,
            brightness = 1.0,
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