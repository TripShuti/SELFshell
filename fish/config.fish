# ============================================================
# fish/config.fish — головний конфіг Fish shell
# ============================================================
function fish_greeting
    # нічого не робимо
    fastfetch
end 

if status is-interactive
    starship init fish | source
end
set -gx STARSHIP_CONFIG ~/.config/starship/config.toml

# uv
fish_add_path "$HOME/.local/bin"

# Автозапуск Hyprland через uwsm (немає display manager):
# boot → getty tty1 (автологін) → fish (login) → exec uwsm start
if status is-login
    and test -z "$WAYLAND_DISPLAY"
    and test (tty) = /dev/tty1
    exec uwsm start hyprland.desktop
end
