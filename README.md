# SELFshell

<p align="center">
  <img src="https://github.com/user-attachments/assets/935367c4-ef2e-46c1-a6e2-c4cc74ecc440" alt="SELFshell demo" width="720">
</p>

A feature-complete Hyprland desktop shell built with **Quickshell and QML**.
Includes a custom lock screen, a built-in idle manager, dynamic
wallpaper-based theming, and a fully configurable top bar — no external bar,
no separate lock/idle daemons.

## Features

**Shell & Bar**
- 13 built-in widgets across three configurable pill sections (left / center / right)
- Drag-and-drop widget reordering via a built-in Settings popup
- System Tray, MPRIS player with cava visualizer, Battery, Bluetooth, Network

**Lock Screen & Idle**
- Native lock screen via `ext-session-lock-v1` with PAM authentication
- Built-in idle manager — lock → DPMS → suspend timeouts (replaces hypridle)
- Media playback pauses idle timers automatically

**Dynamic Theming**
- Wallpaper-based palette generation via `matugen`
- Live reload — terminal (Kitty), prompt (Starship), file manager (Yazi) all update
- No restart required

**Hardware**
- Monitor brightness via `ddcutil` with smooth sub-stepping
- Blue-light filter via `hyprsunset` (3500K–6500K slider)
- Power actions: Shutdown, Reboot, Suspend, Logout, Lock

**Installer & CLI**
- `install.sh` — full setup from a fresh Arch install (greetd, services, cursor, AUR packages)
- `selfshell doctor` — runtime diagnostics (dependencies, services, hardware)
- `selfshell update`, `selfshell lock`, `selfshell reload` — all operations from CLI

<details>
<summary>Genshin Impact widget (optional)</summary>

- Real-time resin tracking with local regeneration calculation (1 resin / 8 min)
- HoYoLAB API sync for expeditions, dailies, teapot coins
- Auto-sync at high resin (≥198) and rate-limit protection
- Pulsing visual indicator at critical resin (≥190)
- Requires credentials in `scripts/.env` (see `.env.example`)
</details>

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
I haven't tested it on an existing setup, but I assume everything works fine there too.

```sh
git clone https://github.com/TripShuti/selfshell
cd selfshell
./install.sh
# follow the prompts, then reboot
```

The script installs all dependencies, copies configs, sets up Bluetooth
and asks whether to install **greetd** with the **tuigreet** TUI login
screen (starts Hyprland via **uwsm** after login). If greetd is declined,
it adds automatic Hyprland startup via uwsm (fish login →
`exec uwsm start hyprland.desktop`) instead. The theme colors and
background are refreshed automatically by `update-palette.sh` on every
wallpaper change. The script finishes with a `selfshell doctor --preboot`
check so you can see any missing pieces before the reboot.

### Manual setup (without install.sh)

Clone and copy the component dirs into `~/.config/` (each repo subdir maps
to `~/.config/<name>`, mirroring what `install.sh` copies):

```sh
git clone https://github.com/TripShuti/selfshell
cp -r selfshell/{quickshell,hypr,fish,kitty,starship,yazi,fastfetch} ~/.config/
```

Then:
- Copy `quickshell/scripts/.env.example` to `.env` and fill in your credentials (if using Genshin widgets).
- Place your wallpapers in `quickshell/wp/`.
- Review and adjust path references in configs.
- Place a wallpaper in `quickshell/wp/current.jpg` for the lock screen background.
- Ensure all dependencies listed in `install.sh` (`PACMAN_DEPS`) are installed.

## Updating an existing setup

Re-running `./install.sh` is safe: existing configs are backed up to
`~/.config/quickshell.bak-<timestamp>` (and `<app>.bak-<ts>` for each
dotfile) before being replaced, and every step is skipped if it is
already done.

To sync a config from a fresh clone of the repository without the installer:

```sh
cp -r quickshell/. ~/.config/quickshell/
selfshell reload
```

If you keep `~/.config/quickshell` as a git clone of the repository,
`selfshell update` (git pull + shell restart) is the shortest path.

The lock screen uses `quickshell/wp/current.jpg`; on a fresh clone it
falls back to the tracked `wp1.jpg` until you pick a wallpaper (via the
Wallpaper Picker or `selfshell palette-reload`).

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
selfshell update         # update config (git pull, or GitHub archive download) + reload
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
| `bibata-cursor-theme` (AUR) | Modern cursor theme (XCURSOR_THEME + gsettings + index.theme) |
| `grim slurp wl-clipboard` | Screenshots & clipboard |
| `ddcutil` | Monitor brightness control |
| `upower` | Battery widget |
| `qt6-5compat` | `Qt5Compat.GraphicalEffects` — lock screen blur (required, shell won't start without it) |
| `greetd greetd-tuigreet` | TUI login screen (starts Hyprland via uwsm) |
| `uwsm` | User session manager (session start from greetd / fallback autostart) |
| `python-requests python-dotenv` | Genshin Impact widget (Hoyolab API) |

## Structure

```
docs/        - documentation (architecture, components, config formats)
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
starship/    - prompt config
yazi/        - file manager config, keybindings, themes
```

## Notes

> **Disclaimer:** Bugs or breakage may occur on your machine. Feel free to use anything you like, but at your own risk.

- `hypr/env.json` — user-level Hyprland settings: terminal/browser/cursor, autostart apps, input devices. If the file is missing, built-in defaults (identical values) are used.
- Genshin Impact widgets require Hoyolab API credentials (see `quickshell/scripts/.env.example`).
- Bluetooth pairing agent (`qs-bt-agent`) is installed as a systemd user service.
