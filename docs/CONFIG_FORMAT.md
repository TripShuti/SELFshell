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
| `btEnabled` | `boolean` | `false` | Bluetooth |
| `netEnabled` | `boolean` | `false` | Network |
| `trayEnabled` | `boolean` | `true` | System tray |
| `batteryEnabled` | `boolean` | `true` | Battery (the widget hides itself when no battery exists) |
| `dndEnabled` | `boolean` | `false` | Do-not-disturb — hides all notifications |
| `timerSoundPath` | `string` | `""` | Custom timer sound (`""` = from assets/) |
| `idleLockTimeout` | `number` | `300` | Idle time before the screen locks, seconds |
| `idleDpmsTimeout` | `number` | `360` | Idle time before the screen turns off (DPMS off), seconds |
| `idleSuspendTimeout` | `number` | `900` | Idle time before suspend, seconds |
| `audioStep` | `number` | `0.05` | Mouse-wheel volume step (0–1) |
| `brightnessStep` | `number` | `5` | Mouse-wheel brightness step (0–100) |
| `barHeight` | `number` | `32` | Bar height in pixels |
| `barRadius` | `number` | `5` | Bar pill corner radius |
| `leftOrder` | `string[]` | — | Widget names in the left pill (including `sep-N`) |
| `centerOrder` | `string[]` | — | Widget names in the center pill |
| `rightOrder` | `string[]` | — | Widget names in the right pill |

Separators look like `sep-N`, where N is a unique numeric ID.
Generated automatically by `addSep()` in AppConfig.

Idle timeouts must be ascending: `idleLockTimeout < idleDpmsTimeout <
idleSuspendTimeout`. The widgets/bar apply `barHeight`/`barRadius` after a
shell restart (they are read at startup).

### Read/write

The file is read at startup through `Quickshell.Io.FileView`.
AppConfig.qml parses the text with `JSON.parse()` in `Component.onCompleted`.
Writing — `JSON.stringify()` + `configFile.setText()`. Details in
[ARCHITECTURE.md #9.2](ARCHITECTURE.md).

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
  "autostart": [
    { "command": "awww-daemon" },
    { "command": "hyprsunset" }
  ],
  "devices": [
    { "name": "e-signal-hator-pulsar", "sensitivity": 0.1,
      "accel_profile": "flat", "scroll_factor": 2 }
  ]
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
| `autostart` | `array` | `[]` | Autostarts on Hyprland start |
| `autostart[].command` | `string` | — | Command |
| `autostart[].workspace` | `number?` | `null` | Workspace (`[workspace N silent]`) |
| `devices` | `array` | `[]` | Input device settings |
| `devices[].name` | `string` | — | Device name (from `hyprctl devices`) |
| `devices[].sensitivity` | `number?` | — | Mouse sensitivity |
| `devices[].accel_profile` | `string?` | — | `flat`/`adaptive` |
| `devices[].scroll_factor` | `number?` | — | Scroll multiplier |

Note: `quickshell` always starts, regardless of `autostart`
(shell infrastructure, not a user choice).

---

## Hyprland: `.conf` files

Standard Hyprland `.conf` format:
- `hyprsunset.conf`: blue-light filter temperature
- `hyprtoolkit.conf`: hyprlauncher theme (colors, font, rounding)

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
