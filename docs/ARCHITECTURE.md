# SELFshell architecture

## 1. Repository layout

```
selfshell/                       # git repo root (cloned into ~/.config)
  ├── quickshell/                # ~/.config/quickshell/ — QML shell
  │   ├── shell.qml              # root component
  │   ├── Bar.qml                # bar (one per monitor; AppConfig, monitors and services live in shell.qml)
  │   ├── VERSION                # project version (read by selfshell)
  │   ├── core/                  # infrastructure (AppConfig, PaletteService,
  │   │                          #   IdleManager, LockContext/Surface, AnimatedPopup,
  │   │                          #   PillBar, HoverItem/Text/Button, ToggleSwitch,
  │   │                          #   KeyboardLayoutState, JsonProcess,
  │   │                          #   WallpaperController, ResolvedIcon, EmptyHint,
  │   │                          #   AudioEq, VertSlider, ...)
   │   ├── widgets/               # bar widgets
   │   ├── popups/                # popup windows (incl. audio/ — AudioSlider/StreamCard/DeviceCard,
  │   │                          #   PactlJsonProc/EmptyState — and settings/, mpris/, control/ sections)
   │   ├── monitors/              # 3 background monitors (Cava, Genshin, SelfTrack)
   │   ├── services/              # systemd units and QML services (qs-bt-agent,
   │   │                          #   TrackListService, KdeConnectService,
  │   │                          #   PowerProfileService, PacmanService, cava-vis.conf)
   │   ├── scripts/               # selfshell CLI, python/js scripts, .env + EqPresets.js + AudioMixerUtils.js
  │   │                          #   + Format.js/SafePath.js and helpers
   │   ├── data/                  # persisted JSON (config + palette in git, the rest runtime)
   │   ├── assets/                # resources (sounds, icons)
   │   └── pam/                   # lock screen PAM config
  ├── hypr/                      # ~/.config/hypr/ — Hyprland configs
  │   ├── hyprland.lua           # root Lua config
  │   ├── env.json               # user settings (browser, terminal,
  │   │                          #   autostarts, devices)
  │   ├── hyprsunset.conf        # blue-light filter
  │   └── modules/               # env, exec, general, binds, animation,
  │                              #   rules + json.lua (env.json parser)
  ├── fish/                      # ~/.config/fish/
  │   ├── config.fish            # main config
  │   ├── conf.d/                # extra configs (palette)
  │   └── functions/             # functions (ytdlp)
  ├── kitty/                     # ~/.config/kitty/
  ├── starship/                  # ~/.config/starship/
  ├── yazi/                      # ~/.config/yazi/
  ├── fastfetch/                 # ~/.config/fastfetch/
  ├── docs/                      # documentation (this folder)
  ├── LICENSE
  ├── README.md
  └── install.sh                 # automated setup
```

Each component reads its config from `~/.config/<component>/`. `install.sh`
copies the files from the matching repo subdirectories into place.

---

## 2. Hyprland — the compositor

Hyprland is configured via Lua + `env.json` (Lua modules) and one `.conf`
file.

### Lua modules (`hypr/modules/`)

| Module | Purpose |
|--------|---------|
| `env.lua` | Reads `env.json`, provides modules: mainMod, terminal, fileManager, browser, cursorTheme/cursorSize, kbLayout/kbOptions, suspendKey, autostarts, devices, windowRules |
| `json.lua` | Minimal JSON parser (no dependencies). Any error → `nil` |
| `exec.lua` | `XCURSOR_*` env + autostart: `sleep 2 quickshell` (always), `sleep 3 lxqt-policykit-agent`, `wl-paste --watch cliphist store` watchers (text + `image/png`), and the list from `env.json` |
| `general.lua` | Window settings: gaps, border, colors, master/dwindle, decorations, input (`kbLayout`/`kbOptions` from `env.json`); `devices[]` from `env.json` |
| `binds.lua` | Keybindings: Print/SUPER+Print screenshots, XF86 volume/brightness (+OSD), launcher (SUPER+R), settings (SUPER+S), control (SUPER+Escape), lock (SUPER+L), clipboard (SUPER+SHIFT+V), browser/terminal/files (SUPER+W/Q/E), workspaces, focus, window movement |
| `animation.lua` | Animation curves (`wind`, `winIn`, `winOut`, `liner`) and styles |
| `rules.lua` | Universal window rules + data-driven per-app rules from `env.json` (`windowRules`) |

### `env.json` — user settings

`~/.config/hypr/env.json` (copied from the repo). If the file is missing or
broken → defaults from `env.lua` (behavior unchanged).
Schema: `mod`, `terminal`, `fileManager`, `browser`, `cursorTheme`,
`cursorSize`, `kbLayout`, `kbOptions`, `suspendKey`, `autostart[]`
(`command`, `workspace`?), `devices[]` (`name`, `sensitivity`,
`accel_profile`, `scroll_factor`), `windowRules[]`.
Details in [CONFIG_FORMAT.md](CONFIG_FORMAT.md).

### `.conf` files

| File | Purpose |
|------|---------|
| `hyprsunset.conf` | Blue-light filter |

> The lock screen (hyprlock) and idle (hypridle) are replaced by QML:
> `LockContext`/`LockSurface` and `IdleManager` in quickshell (see §9.6–9.7).

---

## 3. Fish — the shell

| File | Purpose |
|------|---------|
| `config.fish` | Runs `fastfetch` on greeting, initializes Starship |
| `conf.d/99-palette.fish` | Terminal colors generated by `update-palette.py` |
| `functions/ytdlp.fish` | `yt-dlp` wrapper for mp3 downloads |

---

## 4. Kitty — the terminal

`kitty.conf` — main config: fish as the shell, Ctrl+C/V, Gruvbox Dark theme
via `current-theme.conf` (auto-generated by `update-palette.py`).

---

## 5. Starship — the prompt

`config.toml` — custom prompt: user@host, directory, git, languages, time.
The `tokyonight` palette is refreshed by `update-palette.py`.

---

## 6. Yazi — the file manager

| File | Purpose |
|------|---------|
| `yazi.toml` | Main config: widgets, openers, plugins, previewers |
| `keymap.toml` | Keybindings (VI-like) |
| `theme.toml` | Theme (generated by `update-palette.py`) |
| `package.toml` | Optional package manifest (currently no third-party dependencies) |

---

## 7. Fastfetch — system info

`config.jsonc` — prints the Arch logo, OS, kernel, host, packages, shell, WM,
uptime, memory, disk. Each module has its own key color.

---

## 8. install.sh — automated setup

Flow:
1. Installs packages from `PACMAN_DEPS` (hyprland, quickshell, kitty, fish, starship, yazi and their dependencies)
2. Copies `quickshell/` to `~/.config/quickshell/`, creates `.env` from `.env.example`
3. Installs `qs-bt-agent` as a systemd user service
4. Installs the `selfshell` CLI (chmod + symlink into `~/.local/bin/`)
5. Offers to copy hypr/kitty/fish/yazi/starship/fastfetch (backing up existing ones)
6. Offers an AUR helper (yay) and the Breeze cursor theme (extra/breeze-cursors)
7. Sets up the login screen: greetd + tuigreet (TUI, starts Hyprland via uwsm), or manual TTY startup; a guarded Fish login block is added only if Fish config exists

Reinstallation replaces selected configs after confirmation and keeps backups
(`*.bak-<timestamp>-<pid>`). File changes roll back on failure; installed packages
and external system settings remain. `--no` exits after a read-only plan. The
installer records component/file ownership and palette opt-in in
`quickshell/.selfshell-install.json`; updates use that manifest.

---

## 9. quickshell architecture (QML shell)

*The QML shell below is the core part of the project.*

### Component tree

```
ShellRoot (shell.qml)
  └── Bar (one per monitor)
      ├── leftPill          ← gradient container
      │   └── RowLayout → Repeater → Loader[widgetComponents[name]] → Widget
      ├── centerPill
      │   └── RowLayout → Repeater → Loader[widgetComponents[name]] → Widget
      └── rightPill
          └── RowLayout → Repeater → Loader[widgetComponents[name]] → Widget
```

### 9.1. Why not static QML elements?
Widgets are loaded dynamically via `Loader` + the `widgetComponents` map
(in Bar.qml). This allows:
- reordering pills and changing their contents without touching code (via Settings)
- enabling/disabling widgets without restarting the shell

Key subtlety: `Layout.fillHeight` must be set on the `Loader` itself, not on
the component inside. Otherwise widgets that read `parent.height` (Mpris,
Audio and others) get 0×0 because of a binding loop
(Loader → item → parent.height → Loader). The `widgetNeedsFillHeight()`
function (in Bar.qml) decides which widgets need this.

---

### 9.2. AppConfig — the data model

`AppConfig` (core/AppConfig.qml) is the single Item holding:
- **state (Enabled)** — `launcherEnabled`, `workspacesEnabled`, etc.
- **order (Order)** — three arrays `leftOrder`, `centerOrder`, `rightOrder`

### Pill membership
There is no separate `pill`/`xPill` property. Membership is defined solely
by which of the three arrays (`leftOrder`/`centerOrder`/`rightOrder`)
contains the widget's name. The `pillOf()` function (in AppConfig.qml)
searches all three; if not found it falls back to `"left"`.

### `activeWidgets` — registry of live instances
When the `Loader` mounts a widget, it calls `registerActive(name, item)`
(in Bar.qml). This assigns a **new whole object**, not a key mutation,
because QML bindings (like `Connections` for onClicked and `anchorItem`
for popups) do not react to key mutation inside a JS object — they need a
fresh object reference.

### Persistence: reading/writing data/config.json

Settings are stored in `data/config.json` (JSON format).
`AppConfig.qml` handles reads/writes via `Quickshell.Io.FileView` with a
`JsonAdapter` (typed properties with factory defaults):

```json
{
  "launcherEnabled": true,
  "workspacesEnabled": true,
  "themeMode": "black",
  "kcdEnabled": false,
  "kcdDndEnabled": false,
  "batteryEnabled": false,
  "animationsEnabled": true,
  "animSpeed": 1.0,
  "preferredPlayer": "selfsonic",
  "leftOrder": ["launcher", "sep-2", "workspaces", "sep-7", "mpris"],
  "centerOrder": ["clock", "sep-5", "timer"],
  "rightOrder": ["tray", "sep-12", "keyboard", "sep-10", "audio", "sep-11", "control"]
}
```

**Reading** — `FileView` + `adapter: JsonAdapter` populates the typed
properties from the file automatically at startup. Live watching is
intentionally off on Quickshell 0.3.0: atomic-rename writes crash the shell
(a use-after-free in the FileView watcher), so manual file edits apply after
a restart.

**Writing** — `saveToFile()` calls `configFile.writeAdapter()`, which
serializes all adapter properties back to disk (missing keys get the
factory defaults). Sliders debounce through `saveSoon()` (400 ms) instead
of writing on every tick.

Why JSON:
- standard parser — no regex hacks
- backward compatibility: unknown fields are simply ignored
- UI writes apply immediately; manual file edits apply after a restart (watcher off, see above)

### Animation system: `AppConfig.anim()`

Every animation duration in the shell goes through the helper
`AppConfig.anim(ms)` (core/AppConfig.qml) instead of a raw number:

```qml
NumberAnimation { duration: appConfig.anim(200) }
```

It returns `Math.round(ms * animSpeed)` when `animationsEnabled` is true
and `0` when it is disabled — so the two settings act as a global master
switch and a duration multiplier. The binding is reactive: moving the
sliders in Settings → Appearance retimes running animations live.

Where the config object is out of reach (core components like
`ToggleSwitch`, `HoverText`, `AnimatedPopup`), the component takes an
optional `property QtObject appConfig` and falls back to the raw
duration when it is null (e.g. `appConfig ? appConfig.anim(200) : 200`).
Bar widgets reach it via `window.appConfig`; settings sections via the
popup root (`root.ac.anim(...)`); popups via their `appConfig` property.

Rules of thumb applied throughout:
- hover feedback: color + scale (`Easing.OutBack`, overshoot ≈ 1.5),
  durations 120–220 ms
- geometry/opacity transitions: `Easing.OutCubic`, 150–350 ms
- slider drags: `Behavior` on the knob is disabled while the drag grab is
  held (`enabled: !grab.pressed`) so the knob never lags behind the cursor
- press feedback: instant-ish color darkening / glyph squash (0.92 scale)

---

All global IPC targets are registered once in `shell.qml`. The bar registry
routes popup and OSD commands to `Hyprland.focusedMonitor`, falling back to
the first available bar. Notification history and pairing requests also have
one shared owner; toasts and pairing dialogs appear on the selected monitor.
`MprisService` selects one player reactively for every bar and media popup.

### 9.3. Monitors — background data collection

Monitors (CavaMonitor, GenshinMonitor, SelfTrackMonitor) are QML components that:
- run a background process (cava, python script)
- constantly update properties (bars, resinText)
- those properties are bound to widgets: Genshin/SelfTrack monitors are
  single instances in `shell.qml` (one process, not one per monitor);
  CavaMonitor is also shared and runs only while at least one bar or popup
  displays its output. Widgets reach them through bindings in `Bar.qml`.

Gated by `Config`: each monitor has a `monitorEnabled` property reading the
corresponding `appConfig.*Enabled`. If the widget is disabled, the monitor
does not spawn its background process (`cavaProcess.running = false`,
timers stopped). Unneeded processes do not linger in memory.

```
GenshinMonitor (in GenshinMonitor.qml)
  ├── mainTimer      — every minute: local resin calc, daily sync check
  ├── highResinTimer — every 8 min: auto-sync when resin ≥ 198
  ├── syncProc       — Process: calls genshin_stats.py sync (background and
  │                    manual refresh; `_syncManual` tells the source apart)
  └── refreshNow()   — manual refresh with a 30 s cooldown
```

Thresholds (in GenshinMonitor.qml): `resinClass = "critical"` at resin ≥ 190
(pulsing highlight in the widget), auto-sync enabled at ≥ 198.
After a rate limit from HoYoLAB, `genshin_stats.py` backs off for 15 min.

CavaMonitor is similar: runs `cava -p cava-vis.conf`, parses the numbers,
smooths them exponentially, exposes `bars`.

---

### 9.4. Popups — popup windows

All popups inherit from `AnimatedPopup.qml` — the base component with:
- opening animation (scale + fade + slide)
- closing animation (reverse)
- shared background (gradient + border)
- screen bounds with overflow scrolling: subclasses declare `preferredWidth`
  and `preferredHeight`; the base constrains window dimensions and keeps
  content at its preferred size, leaving nested lists unchanged at normal sizes
- Escape handling
- focus via `HyprlandFocusGrab` (explicit compositor grab): the classic
  xdg keyboard grab needs an input serial from the parent window, which
  does not exist when a popup is opened over IPC from a cold start —
  keybind opens silently failed until the bar was clicked once. With
  `grabFocus: false` + focus grab, keybind opens work immediately, and
  outside clicks still dismiss with animation (via `cleared`). The grab
  is (re)armed by a short timer after showing: activating it synchronously
  with `visible` is lost because the surface is not mapped yet.

Popups, toasts and OSD share the same visual language: `bg0H` gradient
(`popupBgLighten`/`toastLighten`/`osdLighten`), `bg2` border,
`popupRadius`/`toastRadius`/`osdRadius`. Glow was removed — it was either
clipped by the Wayland surface or invisible behind the opaque background.

Each popup is attached to a widget via `anchorItem` — e.g.
`calendarPopup.anchorItem = root.clockWidget`. The popup appears below/above
the widget. The link is wired via `Connections` on click. Anchored popups
set `positionOnShow: true` instead of a manual `onVisibleChanged` handler;
screen-centered popups (mixer, settings, pairing, launcher, …) pass
`centerScreen` and call `centerOnScreen()` — the screen is passed
explicitly so multi-monitor placement stays correct.

Keyboard layout has one shared state (`core/KeyboardLayoutState.qml`):
the bar widget, the layout popup and the lockscreen badge all read it.
Left-click cycles (`cycleNext()`), right-click opens the popup/list
(`refreshMenu()` + `switchTo(index)`).

Clipboard history (`ClipboardPopup`) is opened by its bar widget or, as a
fallback, by the `SUPER+SHIFT+V` keybind via `qs ipc call clipboard toggle`
(`IpcHandler` in `shell.qml`, routed to the focused monitor) and anchored below the control-center widget.
The history itself is gathered by `cliphist`, fed by two
`wl-paste --watch cliphist store` watchers started in `exec.lua` (one for
text, one for images). Clicking an entry pipes it back into the clipboard
(`cliphist decode <id> | wl-copy`); a hover button deletes the entry by
feeding its id to `cliphist delete` through stdin.

---

### 9.5. Settings — sections

SettingsPopup is a fixed-size popup (760x560) with a sidebar of sections,
each loaded as a separate file via `Loader` (`settings/*.qml`, each gets
`sys` = the popup root):
- **Bar** — height, pill radius, edge margin, padding, spacing, bar
  position (top/bottom), auto-hide, pill visibility (left/center/right),
  **Layout** drag-and-drop (widget order between pills, pool disables,
  separators via "+" button), **Pills Appearance** (bg opacity, gradient,
  border) and **Separators**
- **Popups** — `Popups` (bg opacity, gradient, radius, border) and
  `Toast & OSD` (radius, gradient)
- **Hyprland** — `Windows` (gaps, border, rounding, opacity, dim, shadows,
  border colors, dwindle/master layout) and `Blur` (size, passes, vibrancy,
  xray, layer blur)
- **Appearance** — `Theme` (`black`/`matugen`), `Scale` (`uiScale`) and
  `Animations` (`animationsEnabled` master switch, `animSpeed` multiplier)
- **Wallpaper** — picker and palette regeneration
- **Behavior** — Do not disturb, idle timeouts (lock/dpms/suspend with
  ordering constraints), wheel steps (volume/brightness), resetting all
  settings to factory defaults
- **System** — power profile selector + auto power-saver, pacman/AUR
  updates, mini-monitoring
- **Binds** — rebindable shell/app shortcuts
- **About** — shell and component versions, machine info, project link

Layout (drag-and-drop) implementation:
- the dragged element is **not filtered** out of the `Repeater` model; it
  stays in place (its visual state is controlled via opacity/height)
- intermediate `readonly property`s are replaced with functions to avoid
  binding loops (QML does not always compute dependencies through
  intermediate properties correctly in this setup)
- a "pill" in Settings terms is a drag-and-drop zone (left/center/right)

---

### 9.6. Lockscreen — hyprlock replacement

QML lock screen built on `WlSessionLock` + `LockContext` (PamContext).
Embedded directly in `shell.qml` — a single process. IPC via `IpcHandler`
for the `lock` command (invoked with `qs ipc call lockscreen lock`
from `binds.lua` and the power buttons). `lockscreen toggle` is kept as
a lock-only alias (no-op when already locked): unlocking over IPC would
let any user process drop the lock without a password — unlock happens
only through PAM (`LockContext.unlocked` → `locked = false`).

```
╔═══════════════════════════════════════════════╗
║           shell.qml (one process)             ║
║  ShellRoot                                    ║
║    ├── LockContext       ← PAM (PamContext)   ║
║    ├── WlSessionLock                          ║
║    │   └── LockSurface (× monitors)           ║
║    ├── IdleManager       ← 3 IdleMonitors     ║
║    ├── IpcHandler "lockscreen"                ║
║    ├── sleepMonitor      ← sleep_guard.py +     ║
║    │                      SplitParser         ║
║    │                      (PrepareForSleep)   ║
║    ├── suspendProc       ← Process            ║
║    ├── Connections       ← unlock→locked=false ║
║    ├── Connections       ← idle→lock/suspend   ║
║    └── Variants → Bar (× monitors)            ║
╚═══════════════════════════════════════════════╝
```

`WlSessionLock.locked` is bound to `LockContext.locked`:
- `LockContext.locked = true` → the compositor hides the Bar, shows LockSurface
- `LockContext.locked = false` → the compositor hides LockSurface, shows the Bar
- Unlock: LockContext.onUnlocked → `locked = false`

A single process solves the disappearing-lock-screen-after-S3-resume issue:
shell.qml freezes/thaws together with the system, WlSessionLock stays
`locked: true`.

#### Why WlSessionLock and not PanelWindow

`PanelWindow` is a layer-shell panel and gives no fail-secure guarantees.
`WlSessionLock` implements `ext-session-lock-v1`: the compositor guarantees
the surface stays locked and does not unlock on a quickshell crash.
If quickshell crashes, the compositor shows a solid color — fail-secure.

#### PAM without the password in argv

`LockContext.qml` uses `Quickshell.Services.Pam.PamContext` instead of an
external `pamtester` — the password goes straight to PAM in process memory,
not through command-line arguments (visible to other processes via
`/proc/<pid>/cmdline`).

The PAM config is a local file `pam/password.conf` inside the quickshell
directory (`auth required pam_unix.so`), not `/etc/pam.d/`.

#### Multi-monitor focus

`LockSurface` has a full-screen `MouseArea` that calls
`hiddenInput.forceActiveFocus()` on click (and closes the layout menu).
Needed because some compositors lose focus on the password field when
switching monitors.

The password pill sits next to a keyboard layout badge (same
`KeyboardLayoutState` as the bar widget): left-click cycles layouts,
right-click opens an inline list. The pill grows with long passwords;
dots auto-scroll to the tail instead of spilling past the edges.

#### fail-secure

If the shell crashes while locked, the compositor keeps an abandoned secure
lock. Restarting the process cannot reliably recover it. End the affected
graphical session from a TTY and log in again (see [recovery](TROUBLESHOOTING.md)).
Automatic file reload is disabled while locked or applying a wallpaper; CLI
update/reload checks lock state and exits through guarded IPC.

#### Preparing for sleep (logind)

`scripts/sleep_guard.py` owns a logind sleep delay-inhibitor and listens for
`PrepareForSleep`. It sends JSON events to `shell.qml`; QML requests the lock
and sends `secure` back only after `WlSessionLock.secure` confirms coverage of
all screens. The helper then closes the inhibitor FD immediately and reacquires
it after resume. Locking remains active after resume. The logind delay has a
system-imposed maximum, so it cannot guarantee coverage if the compositor hangs.

Idle, power-menu and keybind suspend requests share `requestSuspend()`, which
waits for secure coverage before invoking systemctl. A five-second timeout cancels
the explicit suspend request; it never substitutes for a secure acknowledgement.

---

### 9.7. IdleManager — hypridle replacement

Three `IdleMonitor` levels instead of `hypridle.conf`:

| Level | Timeout | Action |
|-------|---------|--------|
| 1 | 300 s | Signal `lockRequested()` → `lockContext.locked = true` |
| 2 | 360 s | `hyprctl dispatch dpms off` (with auto-restore) |
| 3 | 900 s | Signal `suspendRequested()` → `lockContext.locked = true`, then `systemctl suspend` |

`IdleManager` does not know about `lockContext`/`sessionLock` — it talks
via signals. Level timeouts of `0` mean "never" (exempt from the
`lock < dpms < suspend` ordering). Media playback pauses all levels
(`mediaPlaying` from `_playingCount`), and `caffeineEnabled` inhibits
everything. `shell.qml` subscribes with `Connections`:

```qml
Connections {
  target: idleManager
  function onLockRequested()      { lockContext.locked = true }
  function onSuspendRequested()   {
    root.requestSuspend()          // wait for WlSessionLock.secure, then suspend
  }
}
```

#### Benefits over hypridle

- one syntax for all levels
- embedded in the shell — zero extra processes

---

### 9.8. Bluetooth Agent

`qs-bt-agent` is a Python script implementing the BlueZ pairing agent.
It runs as a **systemd user service**, not through Hyprland `exec-once`.

Why a separate process + systemd instead of exec-once:
- the agent must be up before any Bluetooth client attempts pairing
- a systemd user service guarantees autostart at login regardless of
  whether Hyprland finished loading
- if the agent crashes, systemd restarts it automatically

#### Secure pairing (KeyboardDisplay)

The agent registers with the `KeyboardDisplay` capability, so BlueZ never
pairs silently (the previous `NoInputNoOutput` setup auto-accepted every
device — "Just Works"). Every pairing attempt now requires explicit user
action through a popup:

| BlueZ call | Popup |
|------------|-------|
| `RequestConfirmation(device, passkey)` | "Confirm this passkey matches" — numeric comparison with the code shown |
| `RequestPinCode` / `RequestPasskey` | input field for legacy devices |
| `RequestAuthorization` | "wants to pair with this computer" |
| `AuthorizeService(device, uuid)` | "requests access to \<service\>" |
| `DisplayPasskey` / `DisplayPinCode` | shows the code to type on the other device |

The handshake between the agent and the QML shell goes through two files
in `$XDG_RUNTIME_DIR/selfshell-pairing/` (`request.json`, `response.json`),
watched by `FileView` on the QML side and a Gio monitor (plus a 1s poll
fallback) on the agent side — no new IPC dependencies:

```
bluetoothd ──► qs-bt-agent ──► request.json ──► PairingAgent.qml
                   ▲                                   │ PairingPopup
                   └────── response.json ◄─────────────┘ (Confirm/Reject)
```

Details that matter:
- agent-side timeout is 55 s, just below bluetoothd's own (~60 s), so a
  rejection always comes from us; the popup shows a countdown bar
- `Cancel()` from bluetoothd closes the popup via a `done` marker
- while the screen is locked the popup is invisible → the request times
  out and is rejected automatically (fail-closed)
- requests are written atomically (tmp + rename) and stale files are
  cleaned up at service start

#### Pairing mode policy

Incoming pairing additionally requires `Pairable: yes`. The Discoverable
toggle in the Bluetooth popup acts as an explicit "pairing mode": turning
it on sets both `Discoverable` and `Pairable`, and when the
`DiscoverableTimeout` (180 s) flips discoverability back off, pairability
follows. Already-bonded devices reconnect without either flag, so normal
daily use never needs pairing mode.

#### Device trust

Trust decides whether an already-bonded device may connect its services
without an authorization popup. It is managed in two places:

- the pairing popup has a "Trust this device" toggle (default on): after
  the user confirms, the agent waits for the bond to complete and writes
  `Device1.Trusted` itself
- the Bluetooth manager shows a lock icon per paired device — clicking it
  toggles trust at any time (e.g. for devices paired before this feature
  existed)

Untrusted devices keep prompting on every service connection; if the
prompt is missed, the connect fails after the 55 s timeout.

---

### 9.9. Phone — kcd / KDE Connect

`services/KdeConnectService.qml` — single instance in `shell.qml` (`enabled: appConfig.cfg.kcdEnabled`, `dnd: appConfig.cfg.kcdDndEnabled`), `KdeConnectWidget.qml` in `Bar.qml` (`kcd` in `allWidgetNames`, `rightOrder`, `widgetNeedsFillHeight`), `popups/KdeConnectPopup.qml` centered `AnimatedPopup`. Notification dedup via stable `payload.key` + timeless content hash (`_notifSeen`, TTL 24h, cap 500); `pendingPairRequest` times out after 35s (daemon kills the request at 30s — holding it longer would turn a late Accept into a new outbound request on kcd 1.18+). Pairing is phone-initiated only (the old Devices section with manual pair/unpair is removed; `kcd pair` in a terminal still works).

* **Daemon:** optional `kcd` (`AUR kcd-bin`, `systemctl --user enable --now kcd`, LAN-only `1716/udp+tcp` `1739:1764/tcp`, no KDE stack, 0% idle when all devices connected). Config `~/.config/kcd/kcd.toml` (`download_dir`, `sftp.mount_dir`, `tcp_port 1716` — read once at startup, no hardcoded paths; a shell reload picks up edits). `kcd --version` check → `installed`, `kcd devices --json` 30s poll + `kcd watch --json` live (battery, device.connected, notification, clipboard, sftp, share.progress). `primaryDeviceId/name` from watch `device.connected`/`battery` + poll `connected`/`state`, `isReachable` from `connected` or battery, `lastClipboard`/`sftpVolumes`/`sftpMountPoint` from watch.
* **Widget:** `KdeConnectWidget.qml` phone/battery icon + `charge%` + reachable dot (`green`/`mutedAlt`), `HoverText` scale, `MouseArea` → `kcdPopup.toggle()`, `IpcHandler kcd toggle` (`qs ipc call kcd toggle`).
* **Popup:** `KdeConnectPopup.qml` battery bar, `Ping` (`kcd ping`), `Ring` (`kcd findmyphone`), `Share` (`zenity/kdialog/yad` → `kcd share`), `Clipboard Push` (`kcd clipboard`), `Files Browse/Mount/Unmount` (`kcd sftp browse/mount/unmount` → local `sftp.mount_dir` vs phone `/storage/emulated/0`), share progress, `lastClipboard`/`sftpMountPoint`, recent notifications + Clear, firewall hint. `xdg-open` allowlist = `download_dir` subtree + `sftp.mount_dir` (both from local `kcd.toml`). `Bar.qml` bridges `onNotificationReceived` → `NotifToast` (DND, `tracked=true`).
* **Install/doctor:** `install.sh` AUR `kcd-bin` prompt + `systemctl --user enable --now kcd`, `scripts/selfshell doctor` `Phone (optional, kcd)` checks `kcd --version`, daemon `systemctl --user is-active kcd`/`pgrep`, `ss :1716`.

### 9.10. AudioEq — 15-band system equalizer

`core/AudioEq.qml` — one shared instance in `shell.qml`, providing real EQ via PipeWire `filter-chain` (`SELFshell_EQ`, 15× `mbeq_1197` LADSPA, `mbeqL`/`mbeqR`).

* **Sink:** static config `~/.config/pipewire/pipewire.conf.d/10-selfshell-eq.conf` (`_ensureConf` + `_confFile` + `systemctl --user restart pipewire` once). Always exists, `enable`/`disable` = pure routing (`pactl set-default-sink` + `move-sink-input`), no `load-module`/`unload`.
* **Bands:** live `pw-cli s <node> 2 {params: ["mbeqL:50Hz...", v, "mbeqR:...", v]}` (`_applyAllNow` 30 entries, `setBand` 2 entries). `EqPresets.js` interpolates Winamp 10→15 bands (log-frequency, `all()` cached per call) + `bandLabels`.
* **Presets:** `Flat` + 17 Winamp classics, `userPresets: {name:[15]}` shadow built-ins, `deletedBuiltins`, `pinned` (chronological chip order), `chipExists`/`isPinned`/`togglePin`/`renamePreset`/`saveChangesTo`/`deletePreset`/`createPreset` (`new`/`new2`…).
* **State:** `data/eq.json` (`enabled`, `preset`, `bands[15]`, `userPresets`, `deletedBuiltins`, `pinned`) via `FileView` (`_stateFile` + `_loadState`/`saveState` + `Flat+bands` migration for removed `Custom`). `enabled` restored via `pw-dump` adoption (`_dumpProc` → `enable` if `enabled` and sink found) + relink (`_findNodeProc` → `_relinkProc`).
* **Auto-relink:** PipeWire node/link-group events (500ms debounce), with `Timer _linkCheckTimer` (60s, `enabled && !busy && _eqNodeId>=0`) + `Process _relinkProc` (`pw-link -o | grep output.filter-chain` → bluetooth sink exclusive when present, otherwise all hardware sinks) keeps `filter-chain` output on correct hardware after headphone/BT hotplug. All sink names in shell snippets go through `_shellQuote()`; `grep` on sink names uses `grep -F`. Triggered also on `onEnabledChanged` / `_findNodeProc` / `_loadState` re-apply.
* **UI:** `popups/MprisPopup.qml` — collapsible EQ section (`eqOpen`/`eqHeight`/`eqTarget:216`, `VertSlider` 15× `20x130`, `Flickable` chip row `pinned→builtins→user`, `+` `createPreset`, `ToggleSwitch` `enable`/`disable`, context menu `pin/rename/save/delete` + `Rename` `TextInput`).

### 9.11. Power profiles — PPD

`services/PowerProfileService.qml` — single instance in `shell.qml`, passed into `Bar` as `powerProfiles`. Wraps `powerprofilesctl get/set` (fixed enum, no root, works on `amd_pstate` and `intel_pstate` alike); tracks `lastManualProfile` + `autoActive` so the battery auto-switch can restore. `popups/settings/SystemSection.qml` — selector + status (governor/EPP read-only from sysfs) + `autoPowerSaver` toggle (`config.json`). The shared `services/BatteryService.qml` drives the auto-switch after parsing a complete UPower response, using low/re-arm hysteresis (≤15% → `power-saver`, charge/≥20% → restore); manual picks always win.

### 9.12. Pacman updates

`services/PacmanService.qml` is a shared service in `shell.qml`. It checks
repository and AUR updates via `pacman_updates.py`, caches only complete results
for 24 hours and retries failures after 15 minutes. Partial AUR failures retain
repository rows with a visible error. Upgrades launch a detached transient user
unit, `selfshell-upgrade.service`, containing Kitty and `pacman_upgrade.sh`.
Reloading QML leaves the upgrade alive; startup reattaches to the unit and a
three-second poll tracks completion. The wrapper also holds a kernel flock to
reject parallel manual upgrades. The UI allows another upgrade after the terminal
closes; a 30-minute timer reports a long run without terminating it. The fixed
terminal title is matched by the floating-window rule and focused after launch.


---

## 10. The `selfshell` CLI

`scripts/selfshell` — a dependency-free CLI (pure bash). Installed by
`install.sh` as a symlink `~/.local/bin/selfshell`. Commands:

| Command | What it does |
|---------|--------------|
| `ipc call <target> <fn> [args]` | Wrapper for `qs ipc call` |
| `lock` / `toggle-lock` | Lock the screen (`qs ipc call lockscreen lock`; `toggle` is a lock-only alias, never unlocks) |
| `launcher` / `settings` | `qs ipc call launcher/settings toggle` |
| `control` / `clipboard` / `kcd` / `audio` | `qs ipc call <target> toggle` (control center, clipboard history, phone popup, audio mixer) |
| `osd volume\|brightness` | `qs ipc call osd volume|brightness` (media-key overlay) |
| `theme list\|status\|set <black\|matugen>` | Theming mode in `data/config.json` (`--theme black` static palette vs `update-palette.sh` regen) |
| `wallpaper list\|current\|set <file>\|random` | Wallpaper picker (respects `themeMode`: wallpaper-only in Black, regen in Matugen) |
| `palette reload\|show\|path` | `qs ipc call palette-reload reload`, dump `palette.json`, print its path |
| `status` | One-line overview: version, `themeMode`, wallpaper, Hyprland, quickshell |
| `config get\|set\|edit\|reset` | Validate and mutate the live AppConfig via IPC, or atomically write while stopped; reset to defaults |
| `services` | `systemctl --user` status of shell services (qs-bt-agent, kcd, pipewire) |
| `doctor` | Diagnostics: dependencies, python modules, session, configs, services, ddcutil. Exit 1 on critical problems |
| `reload` | Guarded exit and `qs -p <config> -d`; serialized with update, refused while locked/busy |
| `update` | Stage a GitHub archive for manifest-owned components, preserve personal state, validate, replace and roll back on startup failure |
| `version [--short]` | Version from a git tag or `VERSION` |
| `completion` | Shell completion script |
| `list` | `qs list` |

Paths are resolved relative to the script itself (`readlink -f`), so the
CLI works both from a repo clone and from `~/.config/quickshell/`.

### Shared wallpaper operation

One `WallpaperController` in `shell.qml` serves all monitors and Settings tabs.
Closing or switching the wallpaper UI leaves the operation alive. QML automatic
reload is paused while applying; guarded CLI reload/update waits until it finishes.
`update-palette.sh` uses kernel flock, so a killed process cannot leave a stale
lock directory. Picker delegates use ListView/GridView virtualization rather than
instantiating and decoding the entire wallpaper collection. `update-palette.py current` selects the desktop source; `lock` selects its static lock-screen frame.
