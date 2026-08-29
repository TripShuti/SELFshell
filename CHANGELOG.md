# Changelog

All notable changes to SELFshell are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Toast/OSD opacity** — `AppConfig.qml` `toastBgOpacity`/`osdBgOpacity` (0.90), `data/config.json`, `CONFIG_FORMAT.md` and `PopupsSection` sliders (0.5–1.0) with live preview (`notify-send` / `qs ipc call osd volume` via `Bar.toast`/`Bar.osd` aliases). `NotifToast`/`OsdPopup` now use `Qt.rgba(..., bgOpacity)` like `AnimatedPopup`.
- **Phone integration (kcd / KDE Connect) v1** — optional headless Go daemon `kcd` (`AUR kcd-bin`, `systemctl --user enable --now kcd`, LAN-only `1716/udp+tcp` `1739:1764/tcp`, no KDE stack, no telemetry, 0% idle when all devices connected) for `battery + ping/ring + share file + notification + clipboard + SFTP`. New `services/KdeConnectService.qml` (single instance in `shell.qml`, `kcd watch --json` + `kcd devices --json` 30s poll, 5× backoff, `primaryDeviceId` from watch `device.connected`/`battery` + devices poll, `lastClipboard`/`sftpVolumes`/`sftpMountPoint`) → `widgets/KdeConnectWidget.qml` (phone/battery icon + charge + reachable dot, draggable across `left/center/right` via `BarSection` `allWidgetNames`, `widgetNeedsFillHeight` includes `kcd`) → `popups/KdeConnectPopup.qml` (centered `AnimatedPopup`, battery bar, Ping (`kcd ping`), Ring (`kcd findmyphone`), Share (`zenity/kdialog/yad` → `kcd share`), Clipboard `Push` (`kcd clipboard`), Files `Browse`/`Mount`/`Unmount` (`kcd sftp browse/mount/unmount` → `~/Downloads/kcd/mnt` local, `/storage/emulated/0` phone, `xdg-open`), share progress, last clipboard/SFTP mount info, recent notifications with Clear, firewall hint). `Bar.qml` bridges `KdeConnectService.onNotificationReceived` → `NotifToast` (DND-respecting, `tracked=true`) + `IpcHandler kcd toggle`, `shell.qml` injects `kdeConnect` into `Bar`, `core/AppConfig.qml` `kcdEnabled` + `rightOrder` includes `kcd`, `data/config.json` `kcdEnabled:false`, `tests/check_config_schema.py` `kcdEnabled`, `docs/CONFIG_FORMAT.md` table, `scripts/selfshell doctor` `Phone (optional, kcd)` section (version, daemon, `ss :1716`), `install.sh` AUR `kcd-bin` prompt + `systemctl --user enable --now kcd`.

### Changed

- **Toast/OSD visuals** — `NotifToast`/`OsdPopup` unified with `AnimatedPopup`: `bg2` + `lighter(..., lighten)` gradient, `bg2`/`green` borders, no glow. `NotifToast` border `green` for visibility, `OsdPopup` `bg2`.
- **Bar auto-hide** — `Bar.qml:100` `hideTimer` polling (400ms) → event-driven `hideDelay` (400ms) + `anyPopupOpenState` (`calendar/audio/bt/net/mpris/.../notifToast/osd`) + `containsMouse` watchers. No wake-ups when idle.
- **PillBar loader** — `PillBar.qml:65` `Loader` now `asynchronous:true`, `active: !isSep`, `visible: status===Ready`, `sourceComponent: widgetComponents[modelData] ?? null` with `needsFillHeight` guard and `Component.onDestruction: unregisterActive`.

### Fixed

- **Bar top position** — `Bar.qml:130` `root.barPos` undefined (always `bottom`) → `root.appConfig.cfg.barPos` (6 places). Top-bar reveal strip, `hiddenMask` and `barContent` slide direction now correct.
- **Active widgets leak** — `Bar.qml:32` `activeWidgets` never deleted on `Loader` destroy → `unregisterActive` + `PillBar` `Component.onDestruction`, stale `Connections`/`anchorItem` fixed. Added `enabled: target!==null` guards for 10 widget `Connections`.
- **Control badge (all)** — `Bar.qml:180` `controlComp unread: root.newNotifs` (only new since last open) → `controlPopup.visible ? 0 : controlPopup.unread` (`ControlPopup.qml:29` `trackedNotifications.length`). Now `ControlWidget` blinks while any unread remains and clears when a notification is read in Telegram/app (external `dismiss` removes from `tracked`), not only after opening the center.
- **Popup glow** — `AnimatedPopup.qml:63` `outerGlow` (always occluded behind opaque `bgRect`) removed; `AppConfig` `popupGlowOpacity`/`toastGlowOpacity` and `PopupsSection` glow sliders removed, `CONFIG_FORMAT.md`/`COMPONENTS.md`/`ARCHITECTURE.md`/`TROUBLESHOOTING.md` updated. `Separator` glow kept.
- **LockSurface** — `LockSurface.qml:114` timers `clockText.text = ...` / `parent.text = ...` broke `SystemClock` binding → removed, `hiddenInput` now two-way synced via `Connections onCurrentTextChanged`, `actions Suspend` no longer re-locks (`qs ipc call lockscreen lock && systemctl suspend` → `systemctl suspend`), `wallpaperImg` `asynchronous:true cache:false`.
- **AudioMixer injection** — `AudioMixerPopup.qml:170` `T="modelData.name"` double-quote injection → `T='...'.replace(/'/g,"'\\''")` single-quote escaped.
- **Clipboard injection** — `ClipboardPopup.qml:88` `cliphist decode/delete` `id` concatenated → `String(id).replace(/'/g,"'\\''")` + single quotes.
- **TimerWidget** — `TimerWidget.qml:58` `PLAYER='ffplay -nodisp ...'` single string with args never executed → `PLAYER='ffplay' PLAYER_ARGS='-nodisp ...'` + `$PLAYER $PLAYER_ARGS "$SOUND"`, `notifyProc.command` now built per run (was stale binding), `onRead/onWheel =>` → `function`.
- **Settings components** — `SetToggle/SetSlider/SetSelect/SetButton/SetCard/SetLabel.qml:12` `property QtObject sys` → `required`, `SetToggle onToggled: v=>` / `SetSlider onPressed/PositionChanged: mouse=>` → `function`.
- **Toast/OSD black** — `NotifToast.qml:130` / `OsdPopup.qml:152` `_top/_base is not defined` in `GradientStop` (scope) → `container._top/_base`, `bg1→bg2 #525256` + solid `color: _top/_base` → `Qt.rgba(..., bgOpacity)` correctly scoped, no longer pure black.
- **Settings PopupsSection** — `PopupsSection.qml:18` preview helpers moved to `root` (`_previewToast/_previewOsd` at root, `root._previewToast()` calls) + `Process` `notify-send`/`qs ipc` so slider moves show toast/OSD live (previously `_previewToast is not defined` and `PopupWindow` conflict when `Settings` open).
- **Network popup** — `NetworkPopup.qml:324` `onToggled: value=>` → `function`.
- **Toast action buttons** — `NotifToast.qml:243` `MouseArea` for default action was outside `container` (sibling of `PopupWindow`), `toastLayout:146` `z:1` didn’t escape parent → `actionArea:225` never received clicks, `Mark as read` triggered default dismiss. Moved `MouseArea` inside `container` before `toastLayout`, added `HoverHandler` for autoClose pause.
- **Toast border/top highlight** — `NotifToast.qml:126` `border.color: green` → `bg2` (`#525256`) to match `AnimatedPopup.qml:88`/`OsdPopup.qml:156` (was distinct), `NotifToast.qml:139` top 1px `color: hoverOverlay` → `gradient: transparent→hoverOverlay→transparent` like `AnimatedPopup.qml:116` so it doesn’t cut `radius:9` corners.
- **PillBar unregisterActive** — `core/PillBar.qml:73` `Component.onDestruction: root.unregisterActive(modelData)` called undefined (`required` `unregisterActive` missing, `Bar.qml` only passed `registerActive`) → added `required property var unregisterActive` and `Bar.qml` passes `unregisterActive: root.unregisterActive` for all three pills, no more `TypeError` on widget hide/destroy.
- **Phone widget clickable** — `Bar.qml:202 widgetNeedsFillHeight` missed `kcd` → `KdeConnectWidget` `0×0 MouseArea` not clickable → added `|| name==="kcd"`.
- **Phone share picker crash** — `KdeConnectPopup.qml:10 FileDialog` (`QtQuick.Dialogs`) crashed quickshell on Wayland → replaced with `zenity/kdialog/yad` via `Process` + `StdioCollector`.
- **Phone popup offline** — `KdeConnectService.qml:70 devicesProc` had no `command` → never polled `kcd devices --json`, `primaryDeviceId` stayed empty and popup showed `Offline`/`No paired device` while widget showed battery via watch → set `command: ["kcd","devices","--json"]`, set `primaryDeviceId/name` from watch `device.connected`/`battery` and `isReachable=true` on battery, fix `onEnabledChanged`/`pollTimer`/`refresh` to set command.
- **Phone popup hover** — `KdeConnectPopup.qml:261,284,513,524` `Ping`/`Ring`/`Mount`/`Unmount` used `hoverOverlay` grey while `Share`/`Browse`/`Push` used `accent` → unified to `accent` + `bg0H` text.
- **Phone SFTP mount path** — popup `Mount: /storage/emulated/0` showed phone path, local is `~/Downloads/kcd/mnt` per `kcd.toml sftp.mount_dir` → now `Local: ~/Downloads/kcd/mnt → Phone: /storage/emulated/0` and click opens local.

### Removed

- **LayoutSection** — `quickshell/popups/settings/LayoutSection.qml` (17k, orphan, merged into `BarSection`) deleted via `git rm`. `SettingsPopup` sections now `Bar,Popups,Hyprland,Appearance,Wallpaper,Behavior,Binds,About`.

## [0.8.0] - 2026-08-28

### Added

- **Blur for bar and popups (Hyprland `layerrule` + `xray`)** — `hypr/modules/rules.lua` now creates two `hl.layer_rule` (`blur` for `PanelWindow` + `blur_popups` for `PopupWindow`) with `xray=true`, `ignore_alpha` from `~/.config/hypr/visual.json` (`layer_ignore_alpha 0.01`, `layer_popups_ignore_alpha 0.05`). `hypr/modules/general.lua` `decoration.blur` now reads `blur_enabled/size/passes/vibrancy/xray/ignore_opacity/popups` from `visual.json`; `quickshell/popups/settings/AppearanceSection` (now `HyprlandSection`) exposes all of them in **Settings → Hyprland → Blur** + **Settings → Appearance → Blur** with live `hyprctl reload` (400 ms debounce) and `layer_xray` toggle.
- **Settings restructure** — `Bar` now consolidates `Size/Position/Pills` + `Layout` (drag-and-drop `left/center/right/pool`) + `Pills Appearance` (`Pill background opacity, gradient, border`) + `Separators`; new top-level sections `Popups` (`Popups` + `Toast & OSD`) and `Hyprland` (`Windows` + `Blur`), `Appearance` trimmed to `Scale` + `Animations`. `SettingsPopup` sections updated to `Bar, Popups, Hyprland, Appearance, Wallpaper, Behavior, Binds, About`; `Layout` as standalone tab removed.
- **EQ preset manager** — save the current bands as a named preset
  (`+` chip), delete/rename/pin presets via right-click (built-ins are
  hidden via `deletedBuiltins` and pinned via `pinned` chronological
  order), user presets persisted in `data/eq.json`.
- **Player selector** — pill under the album art showing the current
  `preferredPlayer`, dropdown directly from the pill listing all present
  MPRIS players (Spotify, selfsonic, browser …). The choice is
  persisted in `config.json` (`preferredPlayer`) and shared with the bar
  widget.

- **Audio equalizer** — a real 15-band system EQ in the media player
  popup (toggle next to the playlist): PipeWire `filter-chain`
  (`SELFshell_EQ`, 15× `mbeq_1197` LADSPA `mbeqL`/`mbeqR`) via static
  `10-selfshell-eq.conf`, band changes apply live via `pw-cli`, existing
  audio streams are moved through the EQ on enable and back on disable
  (with `_savedSink` fallback), 17 Winamp-classic presets plus user
  presets, persisted in `data/eq.json`. Auto-relinks `filter-chain`
  output on headphone/BT hotplug (exclusive BT vs all hardware). Requires
  `swh-plugins` (added to the installer and `selfshell doctor`).

### Changed

- **Bar/Pill visuals** — `PillBar` now uses `ClippingRectangle` + outer `outline` (`width: bg + 2*borderWidth` centered) so `barBorderWidth` is a true outer stroke that doesn't eat content or move the pill (`implicitWidth` without `+2*border`), gradient alpha encoded in color (`Qt.rgba(..., bgOpacity)`) instead of `Item.opacity` so `layerrule:ignore_alpha` is predictable, `antialiasing`/`smooth` + `layer.smooth` for xray blur; `barHeight` vs `pillHeight` free-space clamping kept.
- **Settings layout** — `Bar` now contains `Layout` drag-and-drop, `Pills Appearance` and `Separators` (moved from `Appearance`); new sections `Popups` and `Hyprland` created, `Appearance` left with `Scale`/`Animations` only.
- **Player selector UX** — moved from clickable album cover + huge
  expanding list below the controls to a dedicated pill under the cover
  (`80×18`, `preferredPlayer` + chevron) with an overlay dropdown
  (`160×` `playerSelTarget`, `mapToItem(layout)`, `z:60`) that doesn't
  push the popup height.
- **EQ preset editing** — moving sliders no longer creates a `Custom`
  preset; the active preset (e.g. `Techno`) stays green, changes are live
  until shell reload. Use context menu `Save changes` to overwrite the
  preset (built-in → user-shadow) or `+` to create `new`/`new2`…. `Custom`
  removed completely (`Flat`+`bands` migration for old `eq.json`).
- **Audio output switching** — `AudioMixerPopup` now moves existing
  `sink-inputs` (`pactl move-sink-input`) and, when EQ is on
  (`default == SELFshell_EQ`), relinks `filter-chain` output
  (`pw-link -d`/`pw-link`) to the selected hardware sink.
- Settings polish: section headers are now uppercase overlines with
  letter spacing, cards have more breathing room between sections, the
  generated `mutedAlt` color is brighter (blend 0.3 → 0.45), and the
  launcher distinguishes hover from the selected row.
- **Mpris pill minimal** — `MprisPopup` player pill under the cover is now transparent (no `bg1`/`green` background or border), text `10→11` (`fg`/`green` when open), chevron `7→8` (`mutedAlt`/`green`), pill `80×18` kept but no pill visuals — less visual noise.
- **Defaults synced to current user** — `quickshell/data/config.json` and `core/AppConfig.qml` defaults updated to live user values (`barHeight 32→36`, `barRadius 5→6`, `barBgOpacity 1.0→0.7`, `barBorderWidth 0→1`, `popupBgOpacity 0.9→0.6`, `popupBgLighten 1.5→1.15`, `popupRadius 10→14`, `toast 6/1.16→9/1.15`, `clipboard true→false`, `tray false→true`), `hypr/modules/general.lua` and `HyprlandSection.qml:hyprDefaults` synced to `visual.json` live values (`gaps_out 1→6`, `border 1→0`, `rounding 0→10`, `dim true`, `opacity 0.95/0.9`, `shadows true→false`, `layout dwindle→master`, `mfact 0.55→0.7`, `blur 6/3/0.35→4/2/0.4`, `blur_xray true→false`, `layer_ignore_alpha 0.01→0`), `data/palette.json` and `wp/wp1.jpg` (1.7M, `wp4.jpg` current) refreshed; docs `ARCHITECTURE.md`/`COMPONENTS.md`/`CONFIG_FORMAT.md` synced.
- **ImageMagick for lock screen** — `install.sh: PACMAN_DEPS` now includes `imagemagick` (`magick` for `current-lock.jpg` generation in `update-palette.sh`).

### Fixed

- **Blur behind bar/pill vs popups** — `AnimatedPopup` and `PillBar` now encode alpha in `Gradient` color (`Qt.rgba(..., bgOpacity)`) instead of `opacity`, `hypr/modules/rules.lua` and `general.lua` read all blur/layer values from `visual.json` (`blur_*`, `layer_*`, `xray`, `new_optimizations:true`), `layerrule` split into `blur` + `blur_popups` with `xray=true`; `update-palette.sh` now `sleep 0.35; hyprctl reload` after `awww img` so `xray` blur no longer shows stale wallpaper; `env_rules_test.lua` updated for `hl.layer_rule` mock.
- **Pill pill corners / border** — `PillBar` double `anchors.margins` (2× inset) removed, `outline` made outer (`width: bg+2*border`) so slider no longer moves the pill, `border.color` no longer multiplied by `bgOpacity` twice, `ClippingRectangle` AA fixed, `glowSize` clamped to `(barHeight-pillHeight)/2` to avoid Hyprland layer clipping.
- **Audio output hotplug** — `filter-chain` (`SELFshell_EQ`) output now
  auto-relinks on headphone/BT hotplug (`_linkCheckTimer` 3s, `bluez`
  exclusive vs all hardware) and `AudioMixerPopup` output switching now
  moves existing `sink-inputs` (`pactl move-sink-input`) and relinks
  `filter-chain` when EQ is on; previously switching default only affected
  new streams and hotplug left EQ linked to a dead/wrong sink (no sound
  on speakers after unplugging headphones/BT, or duplicate BT+speakers).
- **EQ `Custom` preset** — removed completely (`Flat`+`bands` migration for
  old `eq.json`); moving sliders no longer creates `Custom`, the active
  preset stays green and changes are live until reload, `Save changes`
  overwrites the preset. Fixed `deletePreset` crash (`unpin` undefined →
  `Flat`), removed 8× `EQ-DBG` `console.warn` spam and dead
  `saveUserPreset`.
- **MPRIS player selector** — pill now shows `preferredPlayer` under the
  cover, dropdown is an overlay (`160×` `playerSelTarget`, `mapToItem`,
  `z:60`) instead of a huge expanding list below the controls; album
  cover is no longer clickable; fixed `modelData.active` vs `active` check
  and `visible:true` dead prop.
- **Dead code** — `MprisWidget` dead `import "../core"` and `required int
  index`, `MprisPopup` dead `index`, `VertSlider` `onValueChanged:
  Qt.binding` leak → declarative `height: track.height*(value-from)/(to-from)`,
  `TrackListService`/`CavaMonitor`/`EqPresets` duplication, docs
  (`CONFIG_FORMAT` EQ path `visual.json`→`data/eq.json`, missing `pinned`,
  `preferredPlayer`, `COMPONENTS` missing `AudioEq`/`VertSlider`/`EqPresets`/`eq.json`,
  `ARCHITECTURE` missing §9.9, `data/config.json` missing `preferredPlayer`).
- Settings popup on multi-monitor setups: each monitor had its own
  section state — edits made in one monitor's popup were lost when
  opening the popup on the other. Sections now re-read their config
  files on every open.
- Bluetooth popup: the device list now re-sorts when devices
  connect/disconnect (previously the order only updated when the device
  list itself changed).
- Launcher: corrected anchor coordinates — the popup was offset by the
  screen origin, which would misplace it on a secondary monitor.
- MPRIS popup: guard the destruction-time player re-detection against a
  dead root (callLater could run after the popup was destroyed).
- Calendar: the task-save callback is cleared when the popup is
  destroyed (a stale callback could crash task saving afterwards).
- Timer widget: horizontal scroll no longer decrements the duration;
  the triple completion sound is intentional and now documented as such.
- Genshin widget: the resin icon no longer stays semi-transparent if the
  critical state ends while the widget is hidden.

### Removed

- **Pill glow** (`barGlowSize`/`barGlowOpacity` + `PillBar` `glowRect`) — was only a `1px` border at distance `glowSize` (clamped to `4px` by `barHeight 36`), `24px` gave same visual as `4px`, glow `opacity` barely toned the pill. Removed from `PillBar.qml`, `AppConfig.qml` (`JsonAdapter` + `defaultCfg`), `Bar.qml` (3× `PillBar` props), `AppearanceSection.qml` (`Bar` card), `quickshell/data/config.json` and docs; `separator` glow kept.
- **Per-app keyboard layout (`appLayout`)** — niche `hypr/modules/rules.lua` `hl.on("window.active")` switching + `hypr/modules/env.lua` `appLayout`/`appLayoutActive` + `hypr/env.json` `appLayout: []` + `docs/CONFIG_FORMAT.md`/`ARCHITECTURE.md`/`COMPONENTS.md` + `tests/check_config_schema.py` + `tests/lua/env_rules_test.lua` (handler). Kept locally in `~/.config` if needed, removed from defaults.

## [0.7.0] - 2026-08-24

### Added

- **Binds** settings section — rebindable shell/app shortcuts (launcher,
  settings, control, lock, clipboard, browser, terminal, files, suspend):
  click a row, press a key (SUPER implied), conflicts detected, applied
  via `~/.config/hypr/binds.json` + `hyprctl reload`.
- **Appearance** section: "Hyprland windows" card — gaps, border size,
  corner rounding, active/inactive opacity, dim, shadows, border colors,
  dwindle/master layout with master ratio/orientation (written to
  `~/.config/hypr/visual.json`, applied via `hyprctl reload`).
- **Secure Bluetooth pairing** — the pairing agent now uses the
  `KeyboardDisplay` capability instead of silent Just Works: every
  attempt shows a confirmation popup (passkey numeric comparison, PIN
  entry for legacy devices, pair/service authorization) with Confirm /
  Reject, a "Trust this device" toggle and a 55 s countdown. Requests
  arriving while the screen is locked are rejected automatically. The
  Discoverable toggle doubles as an explicit "pairing mode": `Pairable`
  follows it and both flags drop together on timeout, so unknown devices
  cannot even start pairing outside that window. The Bluetooth manager
  also shows a per-device lock icon to toggle trust at any time.
- **About** section: "Updates" status row — compares the installed version
  with `main` and suggests `selfshell update` when a new version is
  available (offline-safe, shows nothing when GitHub is unreachable).
- **Appearance** section: "Animations" card — global `animationsEnabled`
  master switch and an `animSpeed` duration multiplier (0.5–2.0×), applied
  to every animation in the shell on the fly.

### Changed

- All shell animations now respect `animationsEnabled`/`animSpeed` via the
  `AppConfig.anim(ms)` helper; disabling animations snaps states instantly
  (useful for low-power and accessibility).
- Animation polish pass: restrained popup overshoot (2.5 → 1.0), hover
  feedback (color + scale) on bar widgets and workspace dots, fade/scale
  transitions instead of hard `visible` toggles in popups, drag-safe slider
  behaviors, press feedback on settings buttons, and a staggered entrance
  fade for the lock screen.

### Fixed

- Clipboard popup: the auto-refresh timer was missing `repeat: true` — the
  list refreshed exactly once per opening; deleting an entry now refreshes
  only after the delete completes (the deleted row used to reappear), and
  a second copy after reopening the popup no longer gets silently dropped.
- Keyboard layout widget: the `hyprctl devices -j` buffer is now cleared
  on every run — leftover chunks from a previous read corrupted the JSON
  and permanently killed click-to-switch until a shell restart.
- Wallpaper popup: applying is guarded while the previous apply is still
  running (the "Setting wallpaper..." status used to stick forever), and
  the wallpaper list is refreshed on every open — new files in `wp/` no
  longer require a shell restart.
- Network connection settings: IPv4/DNS/security fields are now cleared
  when the popup opens — a failed fetch could show the previous network's
  addresses, which could then be saved into the wrong profile.
- Genshin widget: the initial sync no longer fires before `config.json`
  loads (it ran even when the widget was disabled), and daily-sync dates
  are built from local time instead of UTC.
- Calendar popup: "today" is recomputed on every open — after midnight the
  highlight used to stay on yesterday's cell.
- Battery widget: the low-battery toast now re-arms only when charging or
  above 20% — a charge hovering at 15% could re-toast on every crossing.
- Cava monitor: crash restarts are capped at 5 attempts — a broken cava
  no longer produces an endless crash-restart loop while audio plays.
- Settings sections: re-entering Appearance showed factory defaults (the
  section re-created before the async config read finished), and
  hand-added keys in `binds.json` / json-only keys in `visual.json`
  (e.g. `rounding_power`) were silently dropped on the next UI write —
  all writes are now full snapshots that preserve unknown keys.
- Bluetooth pairing popup: the passkey prompt is now centered on screen
  instead of sticking to the top-left corner, and it no longer stacks on
  top of the Bluetooth manager popup.

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