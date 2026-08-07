# SELFshell

<p align="center">
  <img src="https://github.com/user-attachments/assets/d5b6e3ae-7b14-4cb0-9859-dc3385b5374c" alt="SELFshell demo" width="720">
</p>



Personal desktop environment configs built around **Hyprland + Quickshell**.

> **Disclaimer:** Bugs or breakage may occur on your machine. Feel free to use anything you like, but at your own risk.

## Features

### Desktop Core
- Custom QML **lock screen** with PAM authentication (`ext-session-lock-v1`)
- Built-in **idle manager** — lock/DPMS/suspend timeouts (configurable in Settings), pauses during media playback
- Per-monitor bar instances via `Quickshell.screens`

### Top Bar
- 13 built-in widgets: Launcher, Workspaces, Clock, Timer, MPRIS (with cava visualizer), Genshin resin, Audio, Control Center, Bluetooth, Network, Keyboard Layout, Battery, System Tray
- Three configurable "pill" sections (left / center / right)
- Drag-and-drop widget reordering and enable/disable via Settings popup
- Settings popup "Behavior" tab: bar height/radius, idle timeouts, wheel step sizes — all persisted to `config.json`

### Popups & Menus
- **Application Launcher** — frequency-sorted search
- **Calendar** — month grid with task management (add / complete / delete)
- **Audio Mixer** — PipeWire sink and application volumes
- **Control Center** — notifications (grouped by app, DND mode, action buttons), brightness (ddcutil), reading mode (hyprsunset), power actions
- **Workspaces** — window list per workspace, move/close/focus windows (right-click on workspace number)
- **Keyboard Layout** — layout list with active highlight (right-click on layout widget)
- **Media Player** — MPRIS controls with cava audio visualization (28 bars)
- **Network & Bluetooth** managers with connection details
- **Wallpaper Picker** — grid view, applies palette on selection
- **Notification Toasts** — animated, with sound, clickable, action buttons

### Genshin Impact
- Real-time resin tracking with local regeneration calculation (1 resin / 8 min)
- HoYoLAB API sync for resin, expeditions, teapot coins, daily commissions
- Auto-sync at high resin (≥198) and rate-limit protection
- Pulsing visual indicator at critical resin (≥190)

### Hardware Control
- Monitor brightness via `ddcutil` with sub-stepping
- Blue-light filter via `hyprsunset` (3500K–6500K)
- Power actions: Shutdown, Reboot, Suspend, Logout, Lock

### Dynamic Theming
- Wallpaper-based color palette via `matugen`
- Live palette reload (no restart required)
- Palette drives all QML UI, plus auto-generates terminal (Kitty), prompt (Starship), and file manager (Yazi) colors

### Persistence
- All state persisted through `Quickshell.Io.FileView` — no shell-level I/O
- Config, calendar tasks, control center state, launcher usage saved to JSON

## Components

| Component | Role |
|-----------|------|
| [Hyprland](https://hyprland.org) | Wayland compositor 
| [Quickshell](https://github.com/Quickshell/Quickshell) | QML-based shell/panel 
| [Kitty](https://sw.kovidgoyal.net/kitty/) | Terminal
| [Fish](https://fishshell.com) | Shell 
| [Starship](https://starship.rs) | Prompt 
| [Yazi](https://yazi-rs.github.io) | File manager 
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info

## Quick start for fresh installed Arch
I haven't tested it on any exist setup, but I assume everything works fine there too.

```sh
git clone https://github.com/TripShuti/SELFshell
cd SELFshell
./install.sh
# follow the prompts, then reboot
```

The script installs all dependencies, copies configs, sets up Bluetooth
and asks whether to install **SDDM** with the SELFshell-themed login
screen (`sddm/` theme — background, palette colors and clock matching
the lock screen). If SDDM is declined, it adds automatic Hyprland
startup via **uwsm** (fish login → `exec uwsm start hyprland.desktop`)
instead. The theme colors and background are refreshed automatically by
`update-palette.sh` on every wallpaper change. The script finishes with
a `selfshell doctor --preboot` check so you can see any missing pieces
before the reboot.

### Manual setup (without install.sh)

Clone to `~/.config/`:

```sh
git clone https://github.com/TripShuti/SELFshell ~/.config
```

Then:
- Copy `quickshell/scripts/.env.example` to `.env` and fill in your credentials (if using Genshin widgets).
- Place your wallpapers in `quickshell/wp/`.
- Review and adjust path references in configs.
- Place a wallpaper in `quickshell/wp/current.jpg` for the lock screen background.
- Ensure all dependencies listed in `install.sh` (`PACMAN_DEPS`) are installed.

## CLI

`install.sh` installs a `selfshell` CLI into `~/.local/bin`:

```sh
selfshell doctor         # check dependencies, config, services, hardware
selfshell doctor --preboot # same, but skip session checks (for installer)
selfshell lock           # lock the screen
selfshell toggle-lock    # lock / unlock toggle
selfshell launcher       # toggle application launcher
selfshell settings       # toggle bar settings popup
selfshell palette-reload # re-read the wallpaper palette
selfshell ipc call <target> <function> [args...]
selfshell reload         # restart quickshell
selfshell update         # git pull + reload
selfshell version        # show version
selfshell list           # list running quickshell instances
```

## Dependencies

All runtime dependencies are handled by `install.sh`. See the `PACMAN_DEPS`
array in the script for the complete list. Key packages:

| Package | Purpose |
|---|---|
| `hyprland quickshell` | Compositor & shell |
| `kitty fish starship yazi` | Terminal, shell, prompt, file manager |
| `networkmanager bluez bluez-utils` | Network & Bluetooth |
| `pipewire wireplumber pipewire-pulse` | Audio |
| `hyprsunset` | Blue-light filter |
| `matugen awww` | Color generation & wallpaper |
| `grim slurp wl-clipboard` | Screenshots & clipboard |
| `ddcutil` | Monitor brightness control |
| `upower` | Battery widget |
| `qt6-5compat` | `Qt5Compat.GraphicalEffects` — lock screen blur (required, shell won't start without it) |
| `sddm` | Themed login screen (theme in `sddm/`) |
| `uwsm` | User session manager (fallback autostart without SDDM) |
| `python-requests python-dotenv` | Genshin Impact widget (Hoyolab API) |

## Structure

```
fastfetch/   - system info config
fish/        - shell config, functions, yt-dlp wrapper
hypr/        - Hyprland (lua module system, env.json for user settings) & hyprsunset configs
install.sh   - automated setup script
kitty/       - terminal config
quickshell/  - QML panels, core, popups, widgets, monitors, scripts, data, assets, services
             - core/ — shell infrastructure (AppConfig, IdleManager, LockScreen, etc.)
             - monitors/ — background data monitors (Cava, Genshin)
             - widgets/ — panel widgets (13 total)
             - popups/ — popup windows (15 total)
             - scripts/ — helper scripts (palette, Genshin, etc.)
             - data/ — persisted state (config.json, calendar-tasks, etc.)
             - assets/ — icons, sounds
             - services/ — system services (qs-bt-agent, cava-vis.conf)
             - pam/password.conf — PAM config for lock screen auth
sddm/        - SDDM theme (login screen matching the shell design)
starship/    - prompt config
yazi/        - file manager config, keybindings, themes
```

## Notes

- `hypr/env.json` — user-level Hyprland settings: terminal/browser/cursor, autostart apps, input devices. If the file is missing, built-in defaults (identical values) are used.
- Genshin Impact widgets require Hoyolab API credentials (see `quickshell/scripts/.env.example`).
- Bluetooth pairing agent (`qs-bt-agent`) is installed as a systemd user service.
