# SELFshell

<p align="center">
  <img src="https://github.com/user-attachments/assets/f2b255d3-7bb4-4c7b-878d-dbde78fb7897" alt="SELFshell demo" width="720">
</p>


Personal desktop environment configs built around **Hyprland + Quickshell**.

> **Disclaimer:** Bugs or breakage may occur on your machine. Feel free to use anything you like, but at your own risk.

## Features

### Desktop Core
- Custom QML **lock screen** with PAM authentication (`ext-session-lock-v1`)
- Built-in **idle manager** — locks after 5min, DPMS off after 6min, suspend after 15min; pauses during media playback
- Per-monitor bar instances via `Quickshell.screens`

### Top Bar
- 12 built-in widgets: Launcher, Workspaces, Clock, Timer, MPRIS (with cava visualizer), Genshin resin, Audio, Control Center, Bluetooth, Network, Keyboard Layout, System Tray
- Three configurable "pill" sections (left / center / right)
- Drag-and-drop widget reordering and enable/disable via Settings popup

### Popups & Menus
- **Application Launcher** — frequency-sorted search
- **Calendar** — month grid with task management (add / complete / delete)
- **Audio Mixer** — PipeWire sink and application volumes
- **Control Center** — notifications, brightness (ddcutil), reading mode (hyprsunset), power actions
- **Media Player** — MPRIS controls with cava audio visualization (28 bars)
- **Network & Bluetooth** managers with connection details
- **Wallpaper Picker** — grid view, applies palette on selection
- **Notification Toasts** — animated, with sound, clickable

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
chmod +x install.sh
./install.sh
# follow the prompts, then reboot
```

The script installs all dependencies, copies configs, sets up Bluetooth
and optionally configures a display manager (`sysc-greet-hyprland` from AUR)
for automatic Hyprland startup.

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
| `python-requests python-dotenv` | Genshin Impact widget (Hoyolab API) |

## Structure

```
fastfetch/   - system info config
fish/        - shell config, functions, yt-dlp wrapper
hypr/        - Hyprland (lua module system) & hyprsunset configs
install.sh   - automated setup script
kitty/       - terminal config
quickshell/  - QML panels, core, popups, widgets, monitors, scripts, data, assets, services
             - core/ — shell infrastructure (AppConfig, IdleManager, LockScreen, etc.)
             - monitors/ — background data monitors (Cava, Genshin)
             - widgets/ — panel widgets (12 total)
             - popups/ — popup windows (12 total)
             - scripts/ — helper scripts (palette, Genshin, etc.)
             - data/ — persisted state (config.json, calendar-tasks, etc.)
             - assets/ — icons, sounds
             - services/ — system services (qs-bt-agent, cava-vis.conf)
             - pam/password.conf — PAM config for lock screen auth
starship/    - prompt config
yazi/        - file manager config, keybindings, themes
```

## Notes

- Quickshell config lives in `~/.config/quickshell/`.
- Lock screen is a custom QML implementation (embedded in `shell.qml` via `WlSessionLock`) with PAM auth, replacing hyprlock/hypridle. Place a wallpaper at `quickshell/wp/current.jpg` for the lock screen background.
- Genshin Impact widgets require Hoyolab API credentials (see `quickshell/scripts/.env.example`).
- Bluetooth pairing agent (`qs-bt-agent`) is installed as a systemd user service.
- See `quickshell/data/` for description of config formats.
