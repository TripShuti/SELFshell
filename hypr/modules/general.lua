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
        rounding       = 2,
        rounding_power = 2,
        active_opacity   = 0.980,
        inactive_opacity = 0.950,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
        blur = {
            enabled  = true,
            size     = 2,
            passes   = 2,
            vibrancy = 1,
        },
    },

    input = {
        kb_layout  = "us, ua",
        kb_options = "grp:alt_shift_toggle",
        follow_mouse = 1,
    },

    animations = {
        enabled = true,
    },
})

hl.device({
    name          = "e-signal-hator-pulsar",
    sensitivity   = 0.1,
    accel_profile = "flat",
    scroll_factor = 2
})