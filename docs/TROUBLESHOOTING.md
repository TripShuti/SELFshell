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

**Fix:** enable Fish generation with `selfshell palette enable fish`, then apply
colors using the action for your current mode:

- **Matugen:** `selfshell wallpaper reload`.
- **Black:** `selfshell theme set black` (also selects the Black wallpaper).
- **Custom:** **Save and apply** in Settings → Appearance, or click a saved theme.

`selfshell palette reload` only rereads the shell palette; it does not regenerate
Fish colors.

## Kitty: theme not applied
**Cause:** `current-theme.conf` does not exist or is not included.

**Fix:**
1. Make sure `kitty.conf` contains `include current-theme.conf`
2. Enable it with `selfshell palette enable kitty` and check `selfshell palette list`.
3. Apply using the appropriate action above: wallpaper reload in Matugen, theme
   set black in Black, or Save and apply / a saved-theme click in Custom.

## Yazi: icons or colors missing
**Cause:** `theme.toml` or `flavors/palette.yazi/flavor.toml` is stale.

**Fix:** back up custom Yazi themes and run `selfshell palette enable yazi`. Then
apply the current mode using the actions above. In Custom, use Save and apply or
click a saved theme; wallpaper reload keeps colors fixed. `palette reload` only
rereads the shell palette.

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
If the shell crashed while locked, the compositor keeps the session locked
with a solid color. Restarting Quickshell cannot reliably recover an abandoned
Wayland lock. Switch to a TTY, log in, identify the affected graphical session
with `loginctl list-sessions`, then end **that session** with
`loginctl terminate-session <session-id>` and log in again. This closes its apps.
Do not kill or reload a working shell while locked.

## quickshell does not see config.json changes
**Symptom:** edited `data/config.json` by hand, but the bar did not update.

**Fix:** use `selfshell config set <key> <value>` for live changes: the CLI
updates the running AppConfig through IPC. `config reset` resets that same
owner. With the shell stopped, these commands validate and write the file
atomically. Stop the shell before using `config edit` or an external editor;
editing behind a running AppConfig can be overwritten by its next save.
File watching remains disabled because atomic-renames crash the watcher in
Quickshell 0.3.0.

## Custom themes

### Wallpaper changes do not change colors

This is expected in **Custom** and **Black**. To generate colors from wallpaper,
select **Matugen** in Appearance or run `selfshell theme set matugen`.
Custom wallpaper set/random/reload only change the image and lock-screen frame.

### Preview changed, but the shell did not

Draft changes are local to the preview. **Save** stores them without applying.
Use **Save and apply** to activate the draft. Clicking a saved entry applies its
stored colors immediately; it discards unsaved draft edits.

### An enabled application still has its old colors

Check `selfshell palette list`. After `palette enable <app>`, use **Save and
apply** or click the desired saved theme. Neither `palette reload` nor
`wallpaper reload` regenerates app themes in Custom. HEX alpha is intentionally
kept only in the shell palette; app integrations use RGB channels.

### A theme was deleted, but the desktop still uses its colors

Deletion removes the preset, not the active palette. Select another saved theme,
apply a new draft, or choose Black/Matugen to change the active colors.

### The library cannot be read or saved

The editor reports malformed data without replacing the file. Back up
`~/.config/quickshell/data/custom-themes.json`, check its JSON syntax and the
[complete schema](CONFIG_FORMAT.md#quickshell-datacustom-themesjson). Every preset
needs a unique nonempty ID, a nonempty name and all 30 valid color fields.

Close Settings before repairing/restoring a library, then run `selfshell reload`
before using the theme controls again; the library does not watch external edits.
For save failures, check available disk space and file permissions. For apply
failures, use the editor's error text and `qs log -p ~/.config/quickshell` to
identify a failing application integration. Some external files may already have
changed if a later integration failed; correct the issue and apply the theme again.

## Wallpaper set but colors did not change in Matugen (half-applied palette)

**Symptom:** Matugen is selected, but a new wallpaper appears with old bar/popup colors.

**Cause:** `update-palette.sh` applies the wallpaper (`awww img` + `current.*`)
*before* `update-palette.py` regenerates the palette. If `matugen` fails
(not installed, bad image), the state is "new wallpaper + stale palette".

**Fix:** the scripts now print `error: ...` instead of failing silently —
check the output of `selfshell wallpaper set <file>` (or `qs log` for the
Settings path) and fix the reported step, then re-run the same command
(it is idempotent; parallel runs are serialized via flock).

## Settings → System shows "Up to date" while offline

**Symptom:** no updates listed although the machine was offline during the check.

**Cause:** an unreachable AUR helper or a missing sync db used to collapse
into an empty list, indistinguishable from "no updates".

**Fix:** current `pacman_updates.py` reports offline/sync failures through
`ok:false` + `error` for repository failures. AUR failures return repository
results with `partial:true` and an error; partial results are not cached as
a complete daily check and are retried after 15 minutes.
`checkupdates` exit 2 still means "up to date". `pacman -Si` enrichment is
forced to `LC_ALL=C` — under a non-English locale repo/description/size
used to come back empty.

## Duplicated Hyprland autostart in fish

**Symptom:** two `uwsm start` blocks in `~/.config/fish/config.fish`
after re-running `install.sh`.

**Fix:** the installer checks for an existing `uwsm start hyprland.desktop`
command before appending its marked block. Remove an old duplicate once,
keeping the guarded tty1 login block. Fish autostart only runs when Fish is
your login shell; otherwise use `uwsm start hyprland.desktop` from a TTY.

## Stale `current.*` wallpapers of mixed formats

**Symptom:** `wp/` contains `current.jpg` and `current.png` at the same time;
lock screen shows an old frame.

**Cause:** fixed — both wallpaper scripts write `current.<ext>` via
tmp+rename under a shared flock and delete stale `current.*` of other
formats. If you edited `wp/` by hand, keep a single `current.*` plus
`current-lock.jpg` (regenerated automatically by the next switch).

## Update rejected or interrupted

A source checkout must be updated with Git outside the live config directory.
For an installed copy, `selfshell update` uses a staged archive and the install
manifest. Resolve reported local edits to managed files before retrying; settings,
secrets and wallpapers are preserved. Unlock the screen and wait for wallpaper
application before update/reload.

After an interrupted transaction, the updater prints its recovery directory:
`~/.config/.selfshell-update-<id>`. Stop the shell while unlocked, then run:

```sh
qs ipc -p ~/.config/quickshell call lockscreen quitIfUnlocked
python3 ~/.config/quickshell/scripts/update_config.py rollback ~/.config/.selfshell-update-<id>
selfshell reload
```

If the live Quickshell directory is missing, use `update_config.py` from a fresh
source checkout instead. Keep the recovery directory until rollback succeeds.
After a power loss, inspect the transaction journal before retrying an update.

## System upgrade terminal and shell reload

Package upgrades run in `selfshell-upgrade.service`, independently of QML.
The UI reattaches after reload and waits until the terminal closes before allowing
a new upgrade. For launch failures, check `journalctl --user -u selfshell-upgrade`.
Closing the terminal during pacman is still an interruption; reload the shell
instead if only its UI needs restarting.
