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
2. Run `selfshell palette reload` (or `selfshell wallpaper set <file>`)

## Yazi: icons or colors missing
**Cause:** `theme.toml` or `flavors/palette.yazi/flavor.toml` is stale.

**Fix:** run `selfshell palette reload`.

## Network does not work after install.sh
**Cause:** `NetworkManager` is not enabled/started.

**Fix:**
```sh
sudo systemctl enable --now NetworkManager
```

## Bluetooth will not pair
**Cause:** `qs-bt-agent` is not running. It is a separate process
(systemd user service), not part of quickshell. Or the adapter is not
in pairing mode: new pairings are only accepted while Discoverable is
on (the Bluetooth popup toggle enables Discoverable + Pairable together;
both drop when the discoverable timeout expires).

**Fix:**
```sh
systemctl --user enable --now qs-bt-agent
```
Then turn on Discoverable in the Bluetooth popup and pair within the timeout.

The agent lives in `~/.config/quickshell/services/qs-bt-agent` and its unit
in `~/.config/systemd/user/qs-bt-agent.service` (both installed by
`install.sh`) — not in `~/.local/bin/`.

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

## Phone (kcd) not pairing / offline

**Symptom:** `KdeConnectPopup` shows `Offline` or `No paired device`, widget dot grey, `kcd devices --json` empty or `connected:false`.

**Cause:** `kcd` daemon not running, firewall blocks `1716/udp+tcp` `1739:1764/tcp`, or phone/PC not on same Wi-Fi.

**Fix:**
```sh
systemctl --user enable --now kcd
kcd devices --json   # should list phone with connected:true
ss -tulpn | grep 1716   # should show kcd listening
# firewall (ufw)
sudo ufw allow 1716/udp && sudo ufw allow 1716/tcp && sudo ufw allow 1739:1764/tcp
# or firewalld
sudo firewall-cmd --permanent --add-service=kdeconnect && sudo firewall-cmd --reload
# pair
kcd pair   # accept on phone, same Wi-Fi
# if phone on different subnet/VPN
kcd connect <pc-ip>   # phone: KDE Connect → Add device by IP
```

**SFTP mount shows `/storage/emulated/0` but folder elsewhere**

**Cause:** `Mount: /storage/emulated/0` is the phone's storage path. Local mount is `sftp.mount_dir` from `~/.config/kcd/kcd.toml` (read live by the popup — no hardcoded default) via `sshfs`. Popup shows `Local: <mount_dir> → Phone: /storage/emulated/0`.

**Fix:** `kcd sftp browse <id>` opens local mount via `xdg-open`. Check `mount | grep kcd` and `kcd sftp info <id>`. Needs `sshfs` (`sudo pacman -S sshfs`).

**SFTP browse hangs then times out (`timed out ... waiting for SFTP response`)**

**Cause:** the daemon asked the phone for SFTP credentials and the phone never answered — the phone-side SFTP plugin is off, the app is battery-restricted, or an approval prompt on the phone was missed. Nothing on the PC side can fix this; the shell only surfaces the timeout.

**Fix:** on the phone, in KDE Connect: enable the SFTP/filesystem plugin, exempt the app from battery optimization, retry Browse and accept any prompt. Verify with `kcd sftp info <id>` (should print IP/user/volumes instead of `no credentials cached`).

**Clipboard push does nothing**

**Cause:** `kcd` needs `wl-clipboard` (Wayland) or `xclip` (X11). Phone's KDE Connect must have Clipboard plugin enabled.

**Fix:** `sudo pacman -S wl-clipboard`, enable Clipboard in phone's KDE Connect plugin list, `kcd clipboard <id>` should push `wl-paste` content.

## Bluetooth pairing fails after restarting bluetooth
**Symptom:** `systemctl restart bluetooth` was run (manually or by a bluez
package update), and new devices can no longer pair. Already-bonded ones
keep working.

**Cause:** a bluetoothd restart forgets all registered agents, but
`qs-bt-agent` registers only at its own startup — it stays "active"
while representing nobody.

**Fix:**
```sh
systemctl --user restart qs-bt-agent
```

## Phone says "incorrect PIN or passkey" when pairing
**Symptom:** the phone reports a wrong PIN although the shell never asks
for one (pairing is Just Works / popup-confirmed).

**Cause:** stale bond state — the phone still holds an old link key for
this computer from an earlier pairing. The Android message is a generic
label for any key-mismatch failure, not an actual PIN prompt. Note that
Android also **hides already-bonded computers from the scan list**, so the
PC may not appear in "Available devices" at all.

**Fix:** remove the old bond on BOTH sides, then pair fresh:
```sh
bluetoothctl remove XX:XX:XX:XX:XX:XX   # PC side
```
and "Forget device" for this computer in the phone's Bluetooth settings.

## Pairing request while the screen is locked
**Symptom:** no pairing popup appeared, the device failed to pair.

**Cause:** the popup lives under the lock surface — it cannot be shown.
Requests arriving while locked are rejected by the agent's 55 s timeout
by design (fail-closed).

**Fix:** none needed; unlock first, then ask the device to pair again.

## Sharp corners on popups (clipped glow)
**Symptom:** sharp "wedges" in the popup corners instead of a smooth rounding.

**Cause:** former `outerGlow` used to overflow the `container` by `-3px` via
`anchors.margins: -3`, but the Wayland surface (`PopupWindow`) is exactly
the size of the `container`.

**Fix:** glow removed in `AnimatedPopup.qml`/`NotifToast.qml`/`OsdPopup.qml` — popups, toasts and OSD now use only `bg2` border and `bg0H` gradient.

## Settings layout broken (content does not fit)
**Symptom:** Settings content overflows the popup, some elements are unreachable.

**Cause:** the `implicitHeight` was fixed and did not account for the real
content height (especially with many widgets in the Pool).

**Fix:** `implicitHeight: 560` with the page Flickable sized from `contentHeight: sectionLoader.item?.implicitHeight ?? 0` (`SettingsPopup.qml`) — adjusts automatically to the content.

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

**Fix:** `selfshell reload`. Changes from the SettingsPopup apply
immediately; manual file edits — after a restart (FileView live-watching
is disabled on Quickshell 0.3.0: atomic-rename writes crash the shell due
to a use-after-free in the file watcher).

## Wallpaper set but colors did not change (half-applied palette)

**Symptom:** new wallpaper on screen, old colors in bar/popups.

**Cause:** `update-palette.sh` applies the wallpaper (`awww img` + `current.*`)
*before* `update-palette.py` regenerates the palette. If `matugen` fails
(not installed, bad image), the state is "new wallpaper + stale palette".

**Fix:** the scripts now print `error: ...` instead of failing silently —
check the output of `selfshell wallpaper set <file>` (or `qs log` for the
Settings path) and fix the reported step, then re-run the same command
(it is idempotent; parallel runs are serialized via a lockdir).

## Settings → System shows "Up to date" while offline

**Symptom:** no updates listed although the machine was offline during the check.

**Cause:** an unreachable AUR helper or a missing sync db used to collapse
into an empty list, indistinguishable from "no updates".

**Fix:** current `pacman_updates.py` reports offline/sync failures through
`ok:false` + `error` (shown in the Updates card) instead of an empty list.
`checkupdates` exit 2 still means "up to date". `pacman -Si` enrichment is
forced to `LC_ALL=C` — under a non-English locale repo/description/size
used to come back empty.

## Duplicated Hyprland autostart in fish

**Symptom:** two `uwsm start` blocks in `~/.config/fish/config.fish`
after re-running `install.sh`.

**Cause:** fixed — the installer now guards its block with
`SELFshell-uwsm-begin/end` markers instead of grepping for `uwsm start`,
so reruns and rollbacks no longer duplicate it. Remove a stale duplicate
by hand once (keep one block).

## Stale `current.*` wallpapers of mixed formats

**Symptom:** `wp/` contains `current.jpg` and `current.png` at the same time;
lock screen shows an old frame.

**Cause:** fixed — both wallpaper scripts write `current.<ext>` via
tmp+rename under a shared lockdir and delete stale `current.*` of other
formats. If you edited `wp/` by hand, keep a single `current.*` plus
`current-lock.jpg` (regenerated automatically by the next switch).

## selfshell update fails with a "not a git clone" error
**Cause:** this was fixed — `selfshell update` now falls back to a GitHub
archive download when the config was installed via `install.sh` (no `.git`).

**Fix:** make sure `selfshell` is up to date:
```sh
curl -fsSL https://raw.githubusercontent.com/TripShuti/SELFshell/main/quickshell/scripts/selfshell -o ~/.config/quickshell/scripts/selfshell && chmod +x ~/.config/quickshell/scripts/selfshell
```
Local files (`config.json`, `.env`, wallpapers) are never overwritten.
