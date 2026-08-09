# Changelog

All notable changes to SELFshell are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Media keys with OSD: `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` /
  `XF86AudioMute` (via `wpctl`) and `XF86MonBrightnessUp` /
  `XF86MonBrightnessDown` (via `ddcutil`) now work and show a 1.5 s overlay
  (icon + value + progress bar, top-center under the bar) via the
  `qs ipc call osd` endpoint.
- Screenshot buttons in the Control Center (full screen and region) — same
  behaviour as `Print` / `SUPER+Print`, with a «Screenshot saved» toast that
  has an **Open** action.
- Polkit agent (`lxqt-policykit`) installed with the other deps and started
  at Hyprland startup; `selfshell doctor` now checks it and warns if it is
  not running.
- Battery widget raises a notification when the battery drops to ≤15% while
  discharging (once per charge cycle; suppressed in DND).
- Clipboard history via `cliphist` + `wl-paste --watch store` watchers
  (text and images): `SUPER+SHIFT+V` opens a popup
  (`qs ipc call clipboard toggle`);
  click copies an entry back into the clipboard, a hover button deletes it.
- Clipboard widget for the bar — a button that opens the clipboard history
  popup (same as `SUPER+SHIFT+V`; the popup anchors to it when present).

### Fixed

- Screenshot buttons in the Control Center no longer freeze or produce empty
  files: the capture commands are now dispatched through
  `hyprctl dispatch hl.dsp.exec_cmd(...)` (the same path as the `Print` /
  `SUPER+Print` keybinds) instead of spawning `slurp` as a QML `Process`
  child, which raced with the still-focusing Control Center popup. The
  result path is delivered via a marker file and the toast appears only
  after the capture finished (a cancelled region selection produces no
  file and no toast).

## [0.1.2] - 2026-08-08

### Added

- Idle timeouts (Lock / DPMS off / Suspend) support `0 = never` — a level
  can be disabled individually in Settings or `config.json`, and a disabled
  level is exempt from the `lock < dpms < suspend` ordering constraint
  (`IdleManager` ignores it and the steppers clamp correctly).

### Fixed

- Wired devices are now detected by `DeviceType.Wired` (the previous
  `DeviceType.Ethernet` never matches Quickshell's enum — network names
  like `wwan0` without an `en`/`eth` prefix were missed).
- `qs-bt-agent` logs a clear reason when it cannot register as the
  default BlueZ agent (conflict with another agent) instead of a bare
  traceback restart loop.

## [0.1.1] - 2026-08-08

### Fixed

- `install.sh` failed with `cp: cannot create directory .../quickshell`
  on fresh users/chroots where `~/.config` does not exist — `backup_and_replace`
  now creates the parent directory first.

## [0.1.0] - 2026-08-08

### Added

- Initial SELFshell 0.1.0 — a feature-complete Hyprland desktop shell built
  with Quickshell/QML:
  - Top bar with 13 widgets across three configurable pill sections and
    drag-and-drop reordering in the built-in Settings popup
  - System tray, MPRIS player with cava visualizer, battery, Bluetooth,
    network, clock, timer, workspaces, keyboard layout, audio
  - Application launcher with usage statistics
  - Control center: network, Bluetooth, audio devices, monitor brightness
    (ddcutil), blue-light filter (hyprsunset), power actions
  - Native lock screen (ext-session-lock-v1 + PAM) with a built-in idle
    manager (lock → DPMS → suspend), media playback pauses idle timers
  - Wallpaper-based dynamic theming via matugen, applied live to the shell,
    Kitty, Starship and Yazi
  - Optional Genshin Impact widget (HoYoLAB API) with local resin tracking
  - `install.sh` with backups, rollback on failure, git-clone-aware updates
    and non-interactive mode (`--yes` / `--no`)
  - `selfshell` CLI: doctor, lock, launcher, settings, palette reload,
    update, reload, version
  - Greetd + tuigreet login screen (optional), uwsm session management