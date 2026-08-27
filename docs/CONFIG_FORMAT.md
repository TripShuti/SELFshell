# Configuration formats

## Quickshell: data/config.json

`data/config.json` — the persistent bar configuration file.
Edited through SettingsPopup (UI) or manually.

### Fields

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `launcherEnabled` | `boolean` | `true` | Launcher |
| `workspacesEnabled` | `boolean` | `true` | Workspaces |
| `mprisEnabled` | `boolean` | `true` | MPRIS player |
| `clockEnabled` | `boolean` | `true` | Clock |
| `timerEnabled` | `boolean` | `true` | Timer |
| `genshinEnabled` | `boolean` | `true` | Genshin widget |
| `keyboardEnabled` | `boolean` | `true` | Keyboard layout |
| `audioEnabled` | `boolean` | `true` | Audio |
| `controlEnabled` | `boolean` | `true` | Control center |
| `clipboardEnabled` | `boolean` | `false` | Clipboard history |
| `btEnabled` | `boolean` | `false` | Bluetooth |
| `netEnabled` | `boolean` | `false` | Network |
| `trayEnabled` | `boolean` | `true` | System tray |
| `batteryEnabled` | `boolean` | `false` | Battery (the widget hides itself when no battery exists) |
| `dndEnabled` | `boolean` | `false` | Do-not-disturb — hides all notifications |
| `timerSoundPath` | `string` | `""` | Custom timer sound (`""` = from assets/) |
| `idleLockTimeout` | `number` | `300` | Idle time before the screen locks, seconds (`0` = never) |
| `idleDpmsTimeout` | `number` | `360` | Idle time before the screen turns off (DPMS off), seconds (`0` = never) |
| `idleSuspendTimeout` | `number` | `900` | Idle time before suspend, seconds (`0` = never) |
| `audioStep` | `number` | `0.05` | Mouse-wheel volume step (0–1) |
| `brightnessStep` | `number` | `5` | Mouse-wheel brightness step (0–100) |
| `barHeight` | `number` | `36` | Bar height in pixels |
| `barRadius` | `number` | `6` | Bar pill corner radius |
| `barPos` | `string` | `"top"` | Bar edge: `top` or `bottom` |
| `edgeMargin` | `number` | `8` | Gap from the screen edge to the side pills, px |
| `pillPadding` | `number` | `8` | Inner padding of a pill, px |
| `contentSpacing` | `number` | `4` | Gap between widgets inside a pill, px |
| `barAutoHide` | `boolean` | `false` | Slide the bar behind the screen edge; hover the 6px edge strip to bring it back |
| `leftPillEnabled` | `boolean` | `true` | Show the left pill as a whole (its widgets stay configured) |
| `centerPillEnabled` | `boolean` | `true` | Show the center pill as a whole |
| `rightPillEnabled` | `boolean` | `true` | Show the right pill as a whole |
| `leftOrder` | `string[]` | — | Widget names in the left pill (including `sep-N`) |
| `centerOrder` | `string[]` | — | Widget names in the center pill |
| `rightOrder` | `string[]` | — | Widget names in the right pill |
| `popupBgOpacity` | `number` | `0.6` | Popup background opacity (0.5–1.0) |
| `popupBgLighten` | `number` | `1.15` | Popup background gradient lighten; 1.0 = flat color (1.0–2.0) |
| `popupRadius` | `number` | `14` | Popup corner radius, px (0–24) |
| `popupBorderWidth` | `number` | `1` | Popup border width, px (0–4) |
| `popupGlowOpacity` | `number` | `0.1` | Popup outer glow opacity; 0 = no glow (0–0.4) |
| `toastRadius` | `number` | `9` | Notification toast corner radius, px (0–24) |
| `toastLighten` | `number` | `1.15` | Toast background gradient lighten (1.0–2.0) |
| `toastGlowOpacity` | `number` | `0.2` | Toast outer glow opacity (0–0.5) |
| `osdRadius` | `number` | `10` | OSD corner radius, px (0–24) |
| `osdLighten` | `number` | `1.5` | OSD background gradient lighten (1.0–2.0) |
| `barLighten` | `number` | `1.3` | Bar pill gradient lighten; 1.0 = flat color (1.0–2.0) |
| `barBgOpacity` | `number` | `0.7` | Pill background opacity multiplier; 1.0 = palette color as-is (0.2–1.0) |
| `barBorderWidth` | `number` | `1` | Pill outline width, px; 0 = no border (0–4) |
| `separatorOpacity` | `number` | `0.65` | Separator line opacity between widget groups (0–1.0) |
| `separatorGlowOpacity` | `number` | `0.1` | Separator glow opacity (0–0.5) |
| `uiScale` | `number` | `1.0` | Global multiplier for all text/icon-glyph sizes in bar, popups and settings (0.8–1.5) |
| `animationsEnabled` | `boolean` | `true` | Master switch for all shell animations (hover, popups, sliders, lock screen) |
| `animSpeed` | `number` | `1.0` | Multiplier for every animation duration; e.g. `1.5` = 50% slower, `0.5` = 2× faster (0.5–2.0) |
| `preferredPlayer` | `string` | `"selfsonic"` | Favorite media player identity substring (`spotify`, `chromium` …), shared by bar widget and popup |

Separators look like `sep-N`, where N is a unique numeric ID.
Generated automatically by `addSep()` in AppConfig.

Idle timeouts must be ascending: `idleLockTimeout < idleDpmsTimeout <
idleSuspendTimeout`. A timeout of `0` disables that level ("never") and
exempts it from the ordering constraint. All bar settings are applied
immediately (the shell reads them reactively); no restart is needed.

### Read/write

The file is read at startup through `Quickshell.Io.FileView` with a
`JsonAdapter` (typed properties with factory defaults). The adapter is the
single source of truth (`window.appConfig.cfg`); writing — `configFile.writeAdapter()` (AppConfig `saveToFile()`). Details in [ARCHITECTURE.md #9.2](ARCHITECTURE.md).

Changes from the SettingsPopup apply immediately and are persisted. Manual
file edits apply after a shell restart: FileView live-watching is disabled
on Quickshell 0.3.0 (atomic-rename writes crash the shell due to a
use-after-free in the file watcher).

All fields are optional: missing or broken ones fall back to the factory
defaults from AppConfig.qml (the shell does not crash).

---

## Hyprland: env.json

`~/.config/hypr/env.json` — user-level Hyprland settings.
Read by `modules/env.lua` through `modules/json.lua`. If the file is
missing or broken → defaults from `env.lua` (identical to the previously
hardcoded values).

```json
{
  "mod": "SUPER",
  "terminal": "kitty",
  "fileManager": "kitty -e yazi",
  "browser": "chromium",
  "cursorTheme": "Bibata-Modern-Classic",
  "cursorSize": 24,
  "kbLayout": "us",
  "kbOptions": "",
  "suspendKey": "",
  "autostart": [
    { "command": "awww-daemon" },
    { "command": "hyprsunset" }
  ],
  "devices": [],
  "windowRules": []
}
```

### Fields

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `mod` | `string` | `"SUPER"` | Hotkey modifier |
| `terminal` | `string` | `"kitty"` | Terminal (binds: SUPER+Q) |
| `fileManager` | `string` | `"kitty -e yazi"` | File manager (SUPER+E) |
| `browser` | `string` | `"chromium"` | Browser (SUPER+W) |
| `cursorTheme` | `string` | `"Bibata-Modern-Classic"` | Cursor theme; `""` — do not set |
| `cursorSize` | `number` | `24` | Cursor size |
| `kbLayout` | `string` | `"us"` | Comma-separated keyboard layouts (`input:kb_layout`) |
| `kbOptions` | `string` | `""` | Keyboard options, e.g. `"grp:alt_shift_toggle"` for layout switching |
| `suspendKey` | `string` | `""` | Extra key that suspends via `systemctl suspend`; `""` — disabled |
| `autostart` | `array` | `[]` | Autostarts on Hyprland start |
| `autostart[].command` | `string` | — | Command |
| `autostart[].workspace` | `number?` | `null` | Workspace (`[workspace N silent]`) |
| `devices` | `array` | `[]` | Input device settings |
| `devices[].name` | `string` | — | Device name (from `hyprctl devices`) |
| `devices[].sensitivity` | `number?` | — | Mouse sensitivity |
| `devices[].accel_profile` | `string?` | — | `flat`/`adaptive` |
| `devices[].scroll_factor` | `number?` | — | Scroll multiplier |
| `windowRules` | `array` | `[]` | Extra `hl.window_rule()` definitions for your apps |
| `windowRules[].name` | `string` | — | Rule name (shown in logs) |
| `windowRules[].match` | `object` | — | Matchers: `class`, `title`, `xwayland`, `float`, … (see `hl.window_rule`) |
| `windowRules[].*` | `*` | — | Rule body: `float`, `center`, `size`, `opacity`, `no_focus`, `suppress_event`, `workspace` … |

Notes:
- `quickshell` always starts, regardless of `autostart`
  (shell infrastructure, not a user choice).

### `windowRules` examples

Every entry is passed to `hl.window_rule()` as-is (Hyprland ≥ 0.52 Lua
API). `match` selects the windows, the rest of the entry is the rule
body — the full windowrule list is documented in the
[Hyprland wiki](https://wiki.hyprland.org/Configuring/Window-Rules/).
Rules apply when the config loads (and on `hyprctl reload`).

Float a calculator, centered, with a fixed size:
```json
{ "name": "calculator-float", "match": { "class": "galculator" },
  "float": true, "center": true, "size": "400 540" }
```

Send an app to a workspace and keep it on top:
```json
{ "name": "discord-workspace", "match": { "class": "discord" },
  "workspace": "5", "pin": true }
```

Match restrictors (`xwayland`, `float`, `fullscreen`, `pin`) narrow the
rule to specific window states — e.g. only XWayland windows without a
class (drag overlays):
```json
{ "name": "fix-xwayland-drags", "match": { "class": "^$", "title": "^$",
    "xwayland": true, "float": true, "fullscreen": false, "pin": false },
  "no_focus": true }
```

Opacity per state, translucent inactive windows:
```json
{ "name": "ghost-inactive", "match": { "class": "kitty" },
  "opacity": "0.95 0.75" }
```


---

## Hyprland: `.conf` files

Standard Hyprland `.conf` format:
- `hyprsunset.conf`: blue-light filter temperature

---

## Hyprland: visual.json

Optional visual overrides for windows/decorations and blur/layer blur,
read by `modules/general.lua` (decoration/blur/shadows) and
`modules/rules.lua` (layerrule blur). Managed by
**Settings → Hyprland → Windows** and **Settings → Hyprland → Blur**
(every change is debounced 400 ms, written atomically and applied via
`hyprctl reload`). The file is absent on a fresh install — all defaults
live in Lua and must stay in sync with `hyprDefaults` in
`HyprlandSection.qml`. After the first change through the UI the file
becomes a full snapshot of the UI-managed keys (explicit values, even
when equal to defaults); JSON-only keys not present in the UI
(e.g. `rounding_power`) are preserved across rewrites.

```json
{
  "gaps_in": 5, "gaps_out": 6, "border_size": 0, "resize_on_border": false,
  "active_opacity": 0.95, "inactive_opacity": 0.9,
  "rounding": 10, "rounding_power": 2.0,
  "dim_inactive": true, "dim_strength": 0.3, "shadows": false,
  "active_border": "rgba(rrggbbff)", "inactive_border": "rgba(rrggbbff)",
  "layout": "master", "mfact": 0.7, "orientation": "left",
  "inactive_timeout": 3, "new_status": "slave", "always_keep_position": false,
  "blur_enabled": true, "blur_size": 4, "blur_passes": 2,
  "blur_vibrancy": 0.4, "blur_vibrancy_darkness": 0.3,
  "blur_noise": 0.02, "blur_contrast": 1.05, "blur_brightness": 1.0,
  "blur_xray": false, "blur_ignore_opacity": false,
  "blur_popups": true, "blur_popups_ignorealpha": 0.1,
  "blur_new_optimizations": true,
  "layer_ignore_alpha": 0, "layer_popups_ignore_alpha": 0.05, "layer_xray": true
}
```

Notes:
- every key is optional; wrong types fall back to the Lua default
- an empty/absent `active_border` keeps the default two-color gradient
  (45°); a color string switches it to a solid color
- `rounding_power` and the fine shadow parameters (range, render_power,
  sharp, color) are JSON-only — intentionally not in the Settings UI
- `blur_*` map to `decoration:blur:*` in `general.lua` (`popups_ignorealpha`
  is the decoration one; the layer thresholds are `layer_*`), `layer_*` map
  to `layerrule` in `rules.lua` (`blur`/`blur_popups` + `ignore_alpha` + `xray`)
- `layout` accepts `dwindle` or `master`; `orientation` —
  `left`/`right`/`top`/`bottom`/`center`

---

## Quickshell: data/eq.json

`quickshell/data/eq.json` — audio equalizer state, written by `core/AudioEq.qml`
(`FileView` at `../data/eq.json`). Created on first `saveState()`.

```json
{
  "enabled": true,
  "preset": "Flat",
  "bands": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
  "userPresets": { "My Preset": [0,1,2, ...] },
  "deletedBuiltins": ["Rock"],
  "pinned": ["Rock"]
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `enabled` | `boolean` | EQ is routed (default sink = `SELFshell_EQ`). Not auto-restored if PipeWire restarted without config, otherwise restored via `pw-dump` adoption |
| `preset` | `string` | Active preset name (`Flat` …) |
| `bands` | `number[15]` | Current 15 gains dB (-12..12, clamped) |
| `userPresets` | `object` | `{name: [15 gains]}` — presets created via `+` or `Save changes` (shadow built-ins on name collision) |
| `deletedBuiltins` | `string[]` | Built-in names hidden via `Delete` |
| `pinned` | `string[]` | Pinned preset names, order = chip row order (chronological) |

---

## Hyprland: binds.json

Optional keybinding overrides read by `modules/binds.lua`. Managed by
**Settings → Binds** in the shell; the file is absent on a fresh install
(all defaults live in Lua). Format: action id → full Hyprland bind
string; `suspend` is a single bare key:

```json
{
  "launcher": "SUPER + T",
  "clipboard": "SUPER + ALT + H",
  "suspend": "XF86Launch1"
}
```

Action ids: `launcher`, `settings`, `control`, `lock`, `clipboard`,
`browser`, `terminal`, `files`, `suspend`. Unknown ids and non-string
or empty values are ignored (the Lua default applies). `SUPER` is always
part of app/shell shortcuts — the Settings UI composes it automatically.
Changes apply via `hyprctl reload` (done by the Settings UI on every
change).

---

## Quickshell: data/config.json → preferredPlayer

The favorite media player (identity substring, e.g. `spotify`,
`selfsonic`, `chromium`) — set from the player popup dropdown, shared
by the bar widget and the player popup. Default: `selfsonic`.

---

## Quickshell: scripts/.env

HoYoLAB credentials for the Genshin widget. Copied from `.env.example`:
`GENSHIN_COOKIE`, `GENSHIN_UID`, `GENSHIN_SERVER`, `GENSHIN_ACT_ID`.
Placeholder values (`your_...`) are detected by `selfshell doctor`.
The file is in `.gitignore` — it never lands in the repository.

---

## Hyprland: Lua modules (`modules/*.lua`)

Lua scripts calling the global `hl.*` functions:

| Function | Purpose |
|----------|---------|
| `hl.curve()` | Bezier curve definition |
| `hl.animation()` | Animation settings |
| `hl.bind()` | Keybinding |
| `hl.config()` | Config block (general, decoration, misc) |
| `hl.device()` | Input device settings |
| `hl.env()` | Environment variable |
| `hl.exec_cmd()` | Command execution |
| `hl.on()` | Event handler |
| `hl.window_rule()` | Window rule |
| `hl.dsp.*` | Actions (exec_cmd, window.close, window.move, focus) |

---

## Fish: `config.fish`

Standard fish script. Runs at shell startup.

---

## Kitty: `kitty.conf`

Standard Kitty format:
```
shell fish
map ctrl+c copy_and_clear_or_interrupt
...
include current-theme.conf
```

---

## Starship: `config.toml`

Standard Starship TOML format. The `tokyonight` palette is refreshed
automatically by `update-palette.py`:

```toml
[palettes.tokyonight]
background = "#2e3132"
foreground = "#dee3e5"
...
```

---

## Yazi: `*.toml`

Standard Yazi TOML format:
- `yazi.toml`: sections `[manager]`, `[preview]`, `[opener]`, `[open]`, `[tasks]`, `[plugin]`, `[input]`, `[confirm]`, `[pick]`, `[which]`
- `keymap.toml`: sections `[mgr]`, `[tasks]`, `[spot]`, `[pick]`, `[input]`, `[confirm]`, `[cmp]`, `[help]`
- `theme.toml`: sections `[flavor]`, `[icon]`

---

## Fastfetch: `config.jsonc`

Standard JSON with comments. Sections: `logo`, `display`, `modules`.
