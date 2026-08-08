# Довідник компонентів

> Доповнюй при створенні/редагуванні файлів.

## Hyprland (`hypr/`)

### Lua-модулі (`modules/`)

| Файл | Що робить |
|------|-----------|
| `env.lua` | Читає `env.json`, віддає модулям: mainMod, термінал, браузер, курсор, автостарти, девайси |
| `json.lua` | Мінімальний JSON-парсер (без залежностей) |
| `exec.lua` | Автозапуск при старті Hyprland (quickshell завжди + `autostart[]` з `env.json`) |
| `general.lua` | Налаштування вікон, проміжків, декору, введення; `devices[]` з `env.json` |
| `binds.lua` | Гарячі клавіші |
| `animation.lua` | Криві та стилі анімацій |
| `rules.lua` | Правила для вікон |

### Конфіги

| Файл | Що робить |
|------|-----------|
| `hyprland.lua` | Кореневий конфіг — підключає модулі |
| `env.json` | Користувацькі налаштування (браузер, термінал, автостарти, девайси) |
| `hyprsunset.conf` | Фільтр синього світла |
| `hyprtoolkit.conf` | Тема для hyprlauncher (зарезервована) |

## Fish (`fish/`)

| Файл | Що робить |
|------|-----------|
| `config.fish` | Головний конфіг (fastfetch, starship) |
| `conf.d/99-palette.fish` | Кольори термінала (генерується `update-palette.py`) |
| `functions/ytdlp.fish` | Обгортка yt-dlp для mp3 |

## Kitty (`kitty/`)

| Файл | Що робить |
|------|-----------|
| `kitty.conf` | Основний конфіг термінала |
| `current-theme.conf` | Тема (генерується `update-palette.py`) |

## Starship (`starship/`)

| Файл | Що робить |
|------|-----------|
| `config.toml` | Конфігурація промпта (палітра оновлюється `update-palette.py`) |

## Yazi (`yazi/`)

| Файл | Що робить |
|------|-----------|
| `yazi.toml` | Основний конфіг файлового менеджера |
| `keymap.toml` | Клавіатурні біндинги |
| `theme.toml` | Тема (генерується `update-palette.py`) |
| `package.toml` | Залежності сторонніх тем |

## Fastfetch (`fastfetch/`)

| Файл | Що робить |
|------|-----------|
| `config.jsonc` | Конфіг системної інформації |

## install.sh

| Файл | Що робить |
|------|-----------|
| `install.sh` | Автоматичне встановлення всього проєкту |

---

## Quickshell (`quickshell/`)

### Кореневі файли

| Файл | Тип | Що робить | Залежності |
|------|-----|-----------|------------|
| `shell.qml` | root | ShellRoot: LockContext + WlSessionLock + Bar + IdleManager + IPC | Quickshell |
| `Bar.qml` | root | Панель, AppConfig, пігулки, монітори, попапи, IPC | Всі віджети, попапи, монітори |
| `VERSION` | data | Версія проєкту (читає CLI `selfshell`) | — |

### `core/` — інфраструктура

| Файл | Тип | Що робить | Залежності |
|------|-----|-----------|------------|
| `AppConfig.qml` | state | Спільний стан панелі: видимість, порядок пігулок; FileView-персистентність у `data/config.json` | Quickshell.Io |
| `PaletteService.qml` | service | Реактивна палітра (FileView + IPC-оновлення) | `data/palette.json` |
| `AnimatedPopup.qml` | util | Базове анімоване попап-вікно (scale+fade+slide, outerGlow) | PaletteService |
| `PillBar.qml` | util | Пігулка бару: Repeater + Loader з `widgetComponents` | AppConfig |
| `HoverItem.qml` | util | Item з вбудованим MouseArea для hover/click | — |
| `HoverText.qml` | util | Text з анімованим hover-кольором/масштабом | — |
| `ToggleSwitch.qml` | util | Перемикач (SettingsPopup) | — |
| `Separator.qml` | util | Вертикальний роздільник для пігулок | PaletteService |
| `GradientSeparator.qml` | util | Градієнтний роздільник | — |
| `BlinkAnimation.qml` | util | Пульсуюча анімація (критична смола) | — |
| `LockContext.qml` | shell | PAM-авторизація та спільний стан локскріна | PamContext |
| `LockSurface.qml` | shell | UI блокування на один монітор | WlSessionLockSurface, LockContext |
| `IdleManager.qml` | shell | Багаторівневе керування бездіяльністю (300/360/900 с) | IdleMonitor |


### Віджети (`widgets/`)

| Файл | Що робить | Дані |
|------|-----------|------|
| `LauncherWidget.qml` | Кнопка відкриття лаунчера | — |
| `WorkspacesWidget.qml` | Список робочих просторів Hyprland | Hyprland |
| `MprisWidget.qml` | Медіаплеєр (поточна пісня) | MprisPopup |
| `ClockWidget.qml` | Годинник | CalendarPopup |
| `TimerWidget.qml` | Таймер | — |
| `GenshinWidget.qml` | Іконка Genshin + смола | GenshinMonitor |
| `KeyboardLayoutWidget.qml` | Індикатор розкладки клавіатури | — |
| `AudioWidget.qml` | Гучність | AudioMixerPopup, CavaMonitor |
| `ControlWidget.qml` | Центр керування | ControlPopup |
| `BluetoothWidget.qml` | Bluetooth | BluetoothPopup |
| `NetWidget.qml` | Мережа | NetworkPopup |
| `TrayWidget.qml` | Системний трей | — |

### Попапи (`popups/`)

| Файл | Що робить | Дані |
|------|-----------|------|
| `LauncherPopup.qml` | Лаунчер додатків | LauncherUsage.js |
| `CalendarPopup.qml` | Календар | `scripts/CalendarTasks.js` |
| `MprisPopup.qml` | Медіаплеєр (деталі + cava-візуалізація) | CavaMonitor |
| `GenshinPopup.qml` | Деталі Genshin, ручний рефреш, чекін | GenshinMonitor, `scripts/genshin_stats.py` |
| `AudioMixerPopup.qml` | Мікшер аудіо | PipeWire |
| `BluetoothPopup.qml` | Керування Bluetooth | bluez |
| `NetworkPopup.qml` | Керування мережами | NetworkManager |
| `NetworkConnectionSettingsPopup.qml` | Деталі конкретного Wi-Fi/підключення | NetworkPopup |
| `ControlPopup.qml` | Сповіщення + швидкі дії | NotificationServer |
| `SettingsPopup.qml` | Налаштування бару (drag-and-drop) | AppConfig |
| `WallpaperPopup.qml` | Вибір шпалер | `scripts/update-palette.sh` |
| `TrayMenuPopup.qml` | Меню системного трею (QML-рендер через QsMenuOpener) | TrayWidget |
| `NotifToast.qml` | Спливаюче сповіщення (тост) | NotificationServer |

### Монітори (`monitors/`)

| Файл | Що робить | Процес |
|------|-----------|--------|
| `CavaMonitor.qml` | Аудіо-візуалізація (cava) | `cava -p cava-vis.conf` |
| `GenshinMonitor.qml` | Поллінг HoYoLAB API, обрахунок смоли | `python3 genshin_stats.py sync` |

### Скрипти (`scripts/`)

| Файл | Мова | Що робить |
|------|------|-----------|
| `selfshell` | Bash | CLI: ipc, doctor, version, reload, update (symlink у `~/.local/bin/`) |
| `genshin_stats.py` | Python | API-клієнт HoYoLAB (resin, sign, daily notes) |
| `tracklist.py` | Python | MPRIS TrackList (черга плеєра) для MprisPopup |
| `update-palette.py` | Python | Генерує палітру та теми для всього проєкту |
| `update-palette.sh` | Bash | Обгортка: matugen + update-palette.py + IPC-оновлення палітри |
| `CalendarTasks.js` | JS | Збереження/завантаження завдань календаря |
| `ControlState.js` | JS | Стан центру керування |
| `LauncherUsage.js` | JS | Частота запуску додатків |
| `.env` | env | HoYoLAB-креди (копіюється з `.env.example`) |

### `services/`

| Файл | Тип | Що робить |
|------|-----|-----------|
| `qs-bt-agent` | Python | BlueZ pairing agent (systemd user-сервіс) |
| `qs-bt-agent.service` | systemd | Юніт для qs-bt-agent |
| `cava-vis.conf` | config | Конфіг cava |
| `TrackListService.qml` | QML | Сервіс MPRIS TrackList (dbus-monitor + жива черга) |

### `data/` — персистентний стан

| Файл | Що зберігає |
|------|-------------|
| `config.json` | Налаштування панелі (видимість, порядок віджетів, звук таймера) |
| `palette.json` | Палітра (генерується `update-palette.sh`) |
| `calendar-tasks.json` | Завдання календаря |
| `control-state.json` | Стан центру керування (muted, яскравість) |
| `launcher-usage.json` | Статистика запусків лаунчера |
