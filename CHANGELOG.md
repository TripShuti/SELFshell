# Changelog

All notable changes to SELFshell are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **About** section: "Updates" status row — compares the installed version
  with `main` and suggests `selfshell update` when a new version is
  available (offline-safe, shows nothing when GitHub is unreachable).

## [0.6.0] - 2026-08-18

### Added

- `selfshell doctor`: Hyprland version check (≥ 0.52 — the config is
  Lua-based) and VERSION drift detection against `main` (warns when the
  installed config was updated by hand and the version file went stale).
- `selfshell update`: refuses to downgrade from a stale archive
  (confirmation prompt), preventing silent config rollbacks.

### Changed

- README declares Hyprland ≥ 0.52 as the required compositor version.
- `docs/CONFIG_FORMAT.md` documents `windowRules` with worked examples
  (float/center/size, workspace/pin, match restrictors, opacity).

## [0.5.0] - 2026-08-18

### Added

- **About** settings section — SELFshell version (from `VERSION`), GitHub
  project link, machine info (OS, kernel) and versions of the shell
  components (Hyprland, Quickshell, Kitty, Yazi); components that are not
  installed show as "—".
- **Appearance** settings section — design beyond the auto palette for the
  bar and popups:
  - **Popups** — background opacity, gradient (lighten), corner radius,
    border width, outer glow (applied to all 15 popups through the
    AnimatedPopup base);
  - **Toast & OSD** — radius, gradient, glow of the notification toast
    and the OSD;
  - **Bar** — pill background opacity, gradient, border width, glow size
    and opacity (the opacity slider dims while size = 0, like in
    Panacea);
  - **Separators** — line opacity and glow of the separators between
    widget groups;
  - **Scale** — global `uiScale` (0.8–1.5): a multiplier for all fonts
    and glyphs in the bar, popups and settings.
- 18 new config keys (`popupBgOpacity`, `popupBgLighten`, `popupRadius`,
  `popupBorderWidth`, `popupGlowOpacity`, `toastRadius`, `toastLighten`,
  `toastGlowOpacity`, `osdRadius`, `osdLighten`, `barLighten`, `barGlowSize`,
  `barGlowOpacity`, `barBgOpacity`, `barBorderWidth`, `separatorOpacity`,
  `separatorGlowOpacity`, `uiScale`) — all with defaults that replicate the
  current look; the old config.json stays compatible.
- Optional `sub` hint in `SetSlider`.

### Fixed

- Settings sliders with a range smaller than 1 (opacity sliders,
  `uiScale`) saturated at maximum halfway down the track and did not
  offer full travel — `span` in `SetSlider` was computed through
  `Math.max(1, ...)` instead of the real `to - from` difference.

## [0.4.0] - 2026-08-15

### Added

- Bar settings system (gear icon in the Control Center or the `settings`
  IPC): three sections:
  - **Bar** — height, pill radius, edge margin, pill padding, content
    spacing, bar position (top/bottom), auto-hide, pill visibility
    (left/center/right);
  - **Layout** — drag-and-drop: widget order between pills, dragging into
    the pool disables the widget, separators are added with the "+"
    button;
  - **Behavior** — Do not disturb, idle timeouts (lock/dpms/suspend with
    ordering constraints), wheel steps (volume/brightness), resetting all
    settings to factory defaults.
- Bar auto-hide: the content slides behind the screen edge with an
  animation and returns on hover over the 6px trigger strip; the hidden
  bar releases the screen (exclusive zone = 0) and the pills do not
  occupy an input region.
- New config format: 8 keys (`barPos`, `edgeMargin`, `pillPadding`,
  `contentSpacing`, `barAutoHide`, `leftPillEnabled`, `centerPillEnabled`,
  `rightPillEnabled`) — all with defaults, the old config.json stays
  compatible.
- Widget hover visuals and the mouse wheel work together with auto-hide
  (a watchdog parent for the pills in the hover chain, events without a
  handler are not intercepted).

### Changed

- The bar config migrated to `JsonAdapter` (Quickshell.Io): UI changes
  save immediately, external manual edits to `config.json` apply after a
  shell restart — `watchChanges` is disabled due to a use-after-free of
  FileView in Quickshell 0.3.0 (atomic file writes crashed the shell).
- Widget visibility is now controlled from Settings (Layout) instead of
  manual config editing.
- A hidden bar returns as soon as any popup is opened by a hotkey
  (Settings/Control/Launcher/Clipboard).

## [0.3.0] - 2026-08-14

### Added

- GIF (animated) wallpapers in the picker and on apply: `awww img` now
  receives the original file instead of a `current.*` copy (awww caches
  frames by path — a fixed-name copy served a stale cache);
  `update-palette.py current` returns the path for the lock screen.
- Static frame `current-lock.jpg` (first frame of the wallpaper via
  magick) for the lock screen — FastBlur cannot render animated sources
  (black screen), so the lock screen blurs the static frame instead of
  the gif.

### Fixed

- The wallpaper picker did not show `.gif` files (extension filter in
  `update-palette.py list`); and, conversely, showed service files
  `current.*` — now any file with the `current` prefix is filtered out
  (including `current-lock.jpg`).
- Changing a gif wallpaper showed frames of the old one (awww cache by
  path `current.*`), the new animation did not move.
- Black lock screen: the wallpaper path was read in `Process.onExited`,
  where stdout is still incomplete — the lock stayed on the fallback; now
  via `StdioCollector.onDataChanged` (like in WallpaperPopup).
- The lock screen stayed black if the fallback placeholder `wp1.jpg` was
  deleted: `update-palette.py current` has a fallback chain (static frame
  → `current.*` → any static wallpaper → any, including gif).
- Wi-Fi password is now persisted on disk: connecting to a new network
  goes through `nmcli dev wifi connect` (profile with `psk-flags=0`)
  instead of the quickshell `connectWithPsk`, which created a profile
  with an agent-owned secret — the password was lost after a restart;
  changing the password in settings also sets `psk-flags 0`.
- Settings of a saved (disconnected) Wi-Fi network showed "Failed to find
  NetworkManager connection profile for this network": the nmcli query
  had an invalid `802-11-wireless.ssid` field ("invalid field") — the
  profile is now looked up with per-profile queries and `-e no` and works
  immediately.
- The Wi-Fi password dialog no longer kicks back to the main menu right
  after clicking Connect: it stays open with a "Connecting..." status,
  keeps the entered password on error for correction, success closes the
  dialog itself; Enter in the password field confirms the connection;
  minimum WPA-PSK length validation (8 characters).

- Tests: fake `upower` battery simulator (`tests/fake_upower.sh`, env-driven
  state/percentage, drop-in PATH replacement) for visual testing of
  BatteryWidget on machines without a battery; Lua unit test for the binds
  (screenshot marker, media keys, clipboard, control center).

## [0.2.0] - 2026-08-09

### Added

- Clipboard history via `cliphist` + `wl-paste --watch store` watchers
  (text and images): `SUPER+SHIFT+V` opens a popup
  (`qs ipc call clipboard toggle`);
  click copies an entry back into the clipboard, a hover button deletes it.
- Clipboard widget for the bar — a button that opens the clipboard history
  popup (same as `SUPER+SHIFT+V`; the popup anchors to it when present).
- The `Print` / `SUPER+Print` screenshot keybinds now write the result path
  into the same marker file as the Control Center buttons, so the
  «Screenshot saved» toast (with an **Open** action) also appears after a
  keybind-taken screenshot.
- Media keys with OSD: `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` /
  `XF86AudioMute` (via `wpctl`) and `XF86MonBrightnessUp` /
  `XF86MonBrightnessDown` (via `ddcutil`) now work and show an overlay
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

### Fixed

- Control Center screenshot buttons no longer freeze or produce empty files:
  captures are dispatched through `hyprctl dispatch hl.dsp.exec_cmd(...)`
  (same path as the keybinds) instead of a QML `Process` child racing with
  the still-focusing popup; a cancelled region selection leaves no file and
  shows no toast. A double-click can no longer kill the interactive `slurp`.
- `qs-bt-agent` logs a clear reason when it cannot register as the default
  BlueZ agent instead of a bare traceback restart loop.
- `doctor` checks the polkit agent via `pgrep -f` (the process name exceeds
  the 15-char `comm` limit, so a name match alone missed it).
- OSD restyled to match the other popups (subtle `bg2` border, radius 10,
  gradient background) and made compact — icon, progress bar and value on
  one line; the window is exactly as tall as its content, so the border is
  never clipped.
- Muted-volume OSD icon: the font in use (JetBrainsMonoNL Nerd Font) has no
  `\uF6A9` glyph, which rendered as a fallback «glass» glyph — muted is now
  `\uF026` tinted red.
- Battery widget no longer reserves a fixed 64px width: it sizes itself from
  its content like the other text widgets.
- Canonical `TripShuti/SELFshell` repository URL everywhere + regression
  test.

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