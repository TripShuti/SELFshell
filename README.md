# SELFshell
[![Demo](https://img.youtube.com/vi/7wSKNmW6L1A/maxresdefault.jpg)](https://youtu.be/7wSKNmW6L1A)
Personal desktop environment configs built around **Hyprland + Quickshell**.

> **Disclaimer:** These configs are tailored to my personal setup. Bugs or breakage may occur on your machine. Feel free to use anything you like, but at your own risk.

## Components

| Component | Role |
|-----------|------|
| [Hyprland](https://hyprland.org) | Wayland compositor |
| [Quickshell](https://github.com/Quickshell/Quickshell) | QML-based shell/panel |
| [Kitty](https://sw.kovidgoyal.net/kitty/) | Terminal emulator |
| [Fish](https://fishshell.com) | Shell |
| [Starship](https://starship.rs) | Prompt |
| [Yazi](https://yazi-rs.github.io) | File manager |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info |

## Dependencies

Runtime dependencies required by widgets and scripts:

| Dependency | Used by | Purpose |
|---|---|---|
| [`NetworkManager`](https://networkmanager.dev) (`nmcli`) | Network popups | WiFi/Ethernet management |
| [`matugen`](https://github.com/InioX/matugen) | `update-palette.py` | Dynamic color generation from wallpaper |
| [`awww`](https://github.com/owl-from-hogvarts/awww) | `update-palette.sh` | Wallpaper setter |
| [`cava`](https://github.com/karlstav/cava) | Audio visualizer widget | Terminal-based audio spectrum |
| `playerctl` | MPRIS popup | Media player controls |
| Python `requests` | `genshin_stats.py` | Hoyolab API HTTP requests |
| Python `python-dotenv` | `genshin_stats.py` | Load credentials from `.env` |

Python packages can be installed via pip:

```sh
pip install requests python-dotenv
```

## Structure

```
fastfetch/   - system info config
fish/        - shell config, functions
hypr/        - Hyprland, hyprlock, hypridle, etc.
kitty/       - terminal config
quickshell/  - QML panels, popups, widgets, scripts
starship/    - prompt config
yazi/        - file manager config + themes
```

## Quick start

Clone to `~/.config/`:

```sh
git clone https://github.com/TripShuti/SELFshell ~/.config
```

Then:

- Copy `quickshell/scripts/.env.example` to `.env` and fill in your credentials (if using Genshin widgets).
- Place your wallpapers in `hypr/wp/` and `quickshell/wp/` (wp1.jpg is kept as placeholder).
- Review and adjust path references in configs (e.g. `hypr/hyprlock.conf`).

## Notes

- Lock screen splash in Ukrainian (`Парольчик..`).
- Genshin Impact widgets require Hoyolab API credentials (see `.env.example`).
