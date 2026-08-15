# Changelog

All notable changes to SELFshell are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Система налаштувань панелі (шестерня в Control Center або IPC `settings`):
  три розділи:
  - **Bar** — висота, радіус пігулок, edge margin, pill padding, content
    spacing, позиція панелі (top/bottom), автоскривання, видимість пігулок
    (left/center/right);
  - **Layout** — drag-and-drop: порядок віджетів між пігулками, перетягування
    у pool вимикає віджет, роздільники додаються кнопкою "+";
  - **Behavior** — Do not disturb, idle-таймаути (lock/dpms/suspend з
    порядковими обмеженнями), кроки колеса (гучність/яскравість), скидання
    усіх налаштувань до заводських.
- Автоскривання панелі: вміст анімовано виїжджає за кромку екрана і
  повертається наведенням на 6px смужку-тригер; прихований бар звільняє
  екран (exclusive zone = 0), пігулки не займають input region.
- Новий формат конфіга: 8 ключів (`barPos`, `edgeMargin`, `pillPadding`,
  `contentSpacing`, `barAutoHide`, `leftPillEnabled`, `centerPillEnabled`,
  `rightPillEnabled`) — усі з дефолтами, старий config.json сумісний.
- Hover-візуали віджетів і колесо миші працюють разом з автоскриванням
  (watchdog-батько пігулок у hover-ланцюзі, події без обробника не
  перехоплюються).

### Changed

- Конфіг панелі мігрував на `JsonAdapter` (Quickshell.Io): зміни з UI
  зберігаються одразу, зовнішні ручні правки `config.json` застосовуються
  після рестарту шела — `watchChanges` вимкнено через use-after-free
  FileView у Quickshell 0.3.0 (атомарний запис файлу крашив шел).
- Видимість віджетів тепер керується з Settings (Layout) замість ручного
  редагування конфіга.
- Прихований бар повертається, щойно відкривається будь-який попап
  гарячою клавішею (Settings/Control/Launcher/Clipboard).

## [0.3.0] - 2026-08-14

### Added

- GIF (аніміровані) шпалери в пікері та при застосуванні: `awww img`
  отримує оригінальний файл замість `current.*` копії (awww кешує кадри
  за шляхом — копія з фіксованим ім'ям віддавала застарілий кеш);
  `update-palette.py current` повертає шлях для lock-скріну.
- Статичний кадр `current-lock.jpg` (перший кадр шпалери через magick)
  для екрану блокування — FastBlur не рендерить анімовані джерела
  (чорний екран), тому lock-скрін блюрить статику замість gif.

### Fixed

- Пікер шпалер не показував `.gif` файли (фільтр розширень у
  `update-palette.py list`); і, навпаки, показував службові `current.*` —
  тепер відсікається будь-який файл з префіксом `current` (зокрема
  `current-lock.jpg`).
- Зміна gif-шпалери показувала кадри старої (awww кеш за шляхом
  `current.*`), нова анімація не рухалась.
- Чорний екран блокування: шлях шпалери зчитувався в `Process.onExited`,
  де stdout ще неповний — лок залишався на fallback-і; тепер через
  `StdioCollector.onDataChanged` (як у WallpaperPopup).
- Лок-скрін зоставався чорним, якщо fallback-заглушка `wp1.jpg` видалена:
  `update-palette.py current` має ланцюг фолбеків (статичний кадр →
  `current.*` → будь-яка статична шпалера → будь-яка, включно з gif).
- Wi-Fi пароль тепер зберігається на диску: підключення до нової мережі йде
  через `nmcli dev wifi connect` (профіль з `psk-flags=0`) замість
  quickshell `connectWithPsk`, який створював профіль з agent-owned
  секретом — пароль губився після рестарту; зміна пароля в налаштуваннях
  теж проставляє `psk-flags 0`.
- Налаштування збереженої (непідключеної) Wi-Fi мережі видавали "Failed to
  find NetworkManager connection profile for this network": nmcli-запит
  мав невалідне поле `802-11-wireless.ssid` ("invalid field") — тепер
  профіль шукається per-profile запитами з `-e no` і працює одразу.
- Діалог пароля Wi-Fi більше не викидає в головне меню одразу після
  кліку Connect: лишається відкритим зі статусом "Connecting...",
  при помилці зберігає введений пароль для виправлення, успіх закриває
  діалог сам; Enter у полі пароля підтверджує підключення; валідація
  мінімальної довжини WPA-PSK (8 символів).

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