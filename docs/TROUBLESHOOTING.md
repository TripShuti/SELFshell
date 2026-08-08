# Troubleshooting

> The first step for any problem — `selfshell doctor`
> (diagnoses dependencies, configs, services, hardware).

## Hyprland: Lua error at startup
**Symptom:** Hyprland starts but throws a Lua error.

**Cause:** syntax error in one of `hypr/modules/*.lua`.

**Fix:**
```sh
hyprctl reload
# or check the syntax:
luac -p ~/.config/hypr/modules/*.lua
```

## Hyprland: keybindings do not work
**Cause:** `mod` is not set in `hypr/env.json` (or the file is broken —
then the defaults from `env.lua` apply).

**Fix:** check `env.json`:
```sh
python3 -m json.tool ~/.config/hypr/env.json
```
Default — `"mod": "SUPER"`.

## Hyprland: bindings stop working with a non-US layout first
**Symptom:** bindings (SUPER+Q/W/E/R, workspace keys…) worked, then died
after editing `env.json`. `hyprctl configerrors` is empty.

**Cause:** Hyprland resolves bind key names against the keyboard layout
active when the config is loaded. If `"kbLayout"` starts with a non-Latin
layout (e.g. `"ua, us"`), the PHYSICAL keys no longer match the bound
symbols while that layout is active.

**Fix:** keep a Latin layout first:
```json
"kbLayout": "us, ua",
"kbOptions": "grp:alt_shift_toggle"
```
then `hyprctl reload`. If per-window layout switching is configured in a
Lua module (`hl.on("window.active")` + `hyprctl switchxkblayout`), switch
to the non-Latin layout by index (`hyprctl switchxkblayout all 1`); the
order in `kbLayout` stays `us`-first. Diagnostic: `hyprctl configerrors`
(empty → not a config syntax problem) and `hyprctl getoption
input:kb_layout`.

## Hyprland: autostarts / cursor / devices disappeared
**Cause:** `hypr/env.json` is broken — `json.lua` returns `nil`,
`env.lua` applies defaults (empty `autostart`/`devices`).

**Fix:** fix the JSON (hint: `python3 -m json.tool
~/.config/hypr/env.json`) or restore the file from the repo, then
`hyprctl reload`.

## Fish: terminal colors do not refresh
**Cause:** `99-palette.fish` was not generated or is stale.

**Fix:**
```sh
~/.config/quickshell/scripts/update-palette.sh ~/.config/quickshell/wp/wp1.jpg
```

## Kitty: theme not applied
**Cause:** `current-theme.conf` does not exist or is not included.

**Fix:**
1. Make sure `kitty.conf` contains `include current-theme.conf`
2. Run `update-palette.py`

## Yazi: icons or colors missing
**Cause:** `theme.toml` or `flavors/palette.yazi/flavor.toml` is stale.

**Fix:** run `update-palette.py`.

## Network does not work after install.sh
**Cause:** `NetworkManager` is not enabled/started.

**Fix:**
```sh
sudo systemctl enable --now NetworkManager
```

## Bluetooth will not pair
**Cause:** `qs-bt-agent` is not running. It is a separate process
(systemd user service), not part of quickshell.

**Fix:**
```sh
systemctl --user enable --now qs-bt-agent
```

If the service is not installed — make sure `qs-bt-agent` is copied to
`~/.local/bin/` or another directory in `PATH`, and the unit lives in
`~/.config/systemd/user/`.

## qs-bt-agent is dead and will not restart
**Symptom:** `systemctl --user status qs-bt-agent` shows `inactive
(dead)`; `journalctl --user -u qs-bt-agent` shows `Unit bluetooth.service
not found` while scheduling the restart (or `Unable to locate
executable .../qs-bt-agent` on installs predating the `services/` split).

**Cause:** the unit ran the agent from the wrong path, or the unit file
is stale. A unit file with `Requires=bluetooth.service` will not restart —
a user manager cannot resolve system services.

**Fix:** install the current unit and start it from scratch:
```sh
systemctl --user disable --now qs-bt-agent
cp ~/.config/quickshell/services/qs-bt-agent.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now qs-bt-agent
```
Verify: `systemctl --user status qs-bt-agent` (active) and
`selfshell doctor` (line `qs-bt-agent (user service) is active`).
(install.sh does this automatically on the next run.)

## Sharp corners on popups (clipped glow)
**Symptom:** sharp "wedges" in the popup corners instead of a smooth rounding.

**Cause:** `outerGlow` used to overflow the `container` by `-3px` via
`anchors.margins: -3`, but the Wayland surface (`PopupWindow`) is exactly
the size of the `container` — the extra pixels were clipped at right angles.

**Fix:** fixed in `AnimatedPopup.qml` — `outerGlow` now uses
`anchors.fill: container`, no overflow.

## Settings layout broken (content does not fit)
**Symptom:** Settings content overflows the popup, some elements are unreachable.

**Cause:** the `implicitHeight` was fixed and did not account for the real
content height (especially with many widgets in the Pool).

**Fix:** replaced with `implicitHeight: contentColumn.implicitHeight + 30` —
adjusts automatically to the content.

## config.json reset to defaults
**Symptom:** after a quickshell update the widget order and enablement reset
to factory values.

**Cause:** broken or empty `data/config.json`. If the file does not parse —
AppConfig applies factory defaults.

**Fix:** check the syntax: `python3 -m json.tool data/config.json`.
If the file is broken — restore from a backup or re-configure via the
Settings UI.

## Genshin Impact: rate limit (error 502)
**Symptom:** GenshinWidget shows "Wait" or "Rate Limit", data stops updating.

**Cause:** the HoYoLAB API limits request frequency. After a 502
`genshin_stats.py` sets a 15-minute backoff.

**Fix:** just wait. Data comes from the local cache (`estimate_local` —
resin calculated from the time of the last successful sync). Everything
recovers automatically within 15 minutes.

## quickshell does not start / crashes
**Fix:**
```sh
selfshell reload       # restart (qs kill + qs -d)
qs log                 # instance logs
```
If the shell crashed while locked, the compositor shows a solid color
(fail-secure). To recover: switch to a TTY and restart:
```sh
killall quickshell && quickshell &
```

## quickshell does not see config.json changes
**Symptom:** edited `data/config.json` by hand, but the bar did not update.

**Fix:** `selfshell reload`. (FileView changes from the UI apply
immediately; manual file edits — after a restart.)

## selfshell update fails with a "not a git clone" error
**Cause:** this was fixed — `selfshell update` now falls back to a GitHub
archive download when the config was installed via `install.sh` (no `.git`).

**Fix:** make sure `selfshell` is up to date:
```sh
curl -fsSL https://raw.githubusercontent.com/TripShuti/selfshell/main/quickshell/scripts/selfshell -o ~/.config/quickshell/scripts/selfshell && chmod +x ~/.config/quickshell/scripts/selfshell
```
Local files (`config.json`, `.env`, wallpapers) are never overwritten.
