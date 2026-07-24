# SELFshell

<p align="center">
  <img src="https://github.com/user-attachments/assets/5883d0b6-d514-438e-a9ce-561e4a54f29e" alt="SELFshell demo" width="720">
</p>

Personal desktop environment configs built around **Hyprland + Quickshell**.

> **Disclaimer:** Bugs or breakage may occur on your machine. Feel free to use anything you like, but at your own risk.

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
- Place your wallpapers in `hypr/wp/` and `quickshell/wp/`.
- Review and adjust path references in configs.
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
| `hyprlock hypridle hyprsunset` | Lock screen, idle, blue-light |
| `matugen awww` | Color generation & wallpaper |
| `grim slurp wl-clipboard` | Screenshots & clipboard |
| `python-requests python-dotenv` | Genshin Impact widget (Hoyolab API) |

## Structure

```
fastfetch/   - system info config
fish/        - shell config, functions, yt-dlp wrapper
hypr/        - Hyprland (lua), hyprlock, hypridle, hyprsunset configs
install.sh   - automated setup script
kitty/       - terminal config
quickshell/  - QML panels, popups, widgets, scripts, qs-bt-agent
starship/    - prompt config
yazi/        - file manager config, keybindings, themes
```

## Notes

- Quickshell config lives in `~/.config/quickshell/`.
- Lock screen splash in Ukrainian (`Парольчик..`).
- Genshin Impact widgets require Hoyolab API credentials (see `quickshell/scripts/.env.example`).
- Bluetooth pairing agent (`qs-bt-agent`) is installed as a systemd user service.
