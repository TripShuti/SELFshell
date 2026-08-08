# Формати конфігурацій

## Quickshell: data/config.json

`data/config.json` — файл персистентної конфігурації панелі.
Редагується через SettingsPopup (UI) або вручну.

### Поля

| Поле | Тип | Дефолт | Призначення |
|------|-----|--------|-------------|
| `launcherEnabled` | `boolean` | `true` | Лаунчер |
| `workspacesEnabled` | `boolean` | `true` | Workspaces |
| `mprisEnabled` | `boolean` | `true` | MPRIS-плеєр |
| `clockEnabled` | `boolean` | `true` | Годинник |
| `timerEnabled` | `boolean` | `true` | Таймер |
| `genshinEnabled` | `boolean` | `true` | Genshin-віджет |
| `keyboardEnabled` | `boolean` | `true` | Розкладка клавіатури |
| `audioEnabled` | `boolean` | `true` | Аудіо |
| `controlEnabled` | `boolean` | `true` | Центр керування |
| `btEnabled` | `boolean` | `false` | Bluetooth (вимкнено за дефолтом) |
| `netEnabled` | `boolean` | `false` | Мережа |
| `trayEnabled` | `boolean` | `false` | Системний трей |
| `batteryEnabled` | `boolean` | `false` | Батарея (прихована, якщо батареї немає) |
| `dndEnabled` | `boolean` | `false` | Режим "не турбувати" — ховає всі сповіщення |
| `timerSoundPath` | `string` | `""` | Кастомний звук таймера (`""` = з assets/) |
| `idleLockTimeout` | `number` | `300` | Час бездіяльності до блокування екрана, секунд |
| `idleDpmsTimeout` | `number` | `360` | Час бездіяльності до вимкнення екрана (DPMS off), секунд |
| `idleSuspendTimeout` | `number` | `900` | Час бездіяльності до suspend, секунд |
| `audioStep` | `number` | `0.05` | Крок гучності колесом миші (0–1) |
| `brightnessStep` | `number` | `5` | Крок яскравості колесом миші (0–100) |
| `barHeight` | `number` | `36` | Висота панелі в пікселях |
| `barRadius` | `number` | `4` | Радіус заокруглення пігулок панелі |
| `leftOrder` | `string[]` | — | Імена віджетів у лівій пігулці (включно з `sep-N`) |
| `centerOrder` | `string[]` | — | Імена віджетів у центральній пігулці |
| `rightOrder` | `string[]` | — | Імена віджетів у правій пігулці |

Роздільники мають вигляд `sep-N`, де N — унікальний числовий ID.
Генеруються автоматично через `addSep()` в AppConfig.

Таймаути бездіяльності мають бути зростаючими: `idleLockTimeout <
idleDpmsTimeout < idleSuspendTimeout`. Віджети/панель застосовують
`barHeight`/`barRadius` після перезапуску шелла (читаються при старті).

### Читання/запис

Файл читається при старті через `Quickshell.Io.FileView`.
AppConfig.qml парсить текст через `JSON.parse()` в `Component.onCompleted`.
Запис — через `JSON.stringify()` + `configFile.setText()`. Деталі — в
[ARCHITECTURE.md #9.2](ARCHITECTURE.md).

Всі поля опціональні: відсутні або пошкоджені замінюються фабричними
дефолтами з AppConfig.qml (шелл не падає).

---

## Hyprland: env.json

`~/.config/hypr/env.json` — користувацькі налаштування Hyprland.
Читається `modules/env.lua` через `modules/json.lua`. Файл відсутній або
пошкоджений → дефолти з `env.lua` (ідентичні значенням, що були
захардкоджені раніше).

```json
{
  "mod": "SUPER",
  "terminal": "kitty",
  "fileManager": "kitty -e yazi",
  "menu": "wofi --show drun",
  "browser": "chromium",
  "cursorTheme": "Capitaine Cursors (Gruvbox)",
  "cursorSize": 24,
  "autostart": [
    { "command": "awww-daemon" },
    { "command": "chromium", "workspace": 2 }
  ],
  "devices": [
    { "name": "e-signal-hator-pulsar", "sensitivity": 0.1,
      "accel_profile": "flat", "scroll_factor": 2 }
  ]
}
```

### Поля

| Поле | Тип | Дефолт | Призначення |
|------|-----|--------|-------------|
| `mod` | `string` | `"SUPER"` | Модифікатор хоткеїв |
| `terminal` | `string` | `"kitty"` | Термінал (binds: SUPER+Q) |
| `fileManager` | `string` | `"kitty -e yazi"` | Файловий менеджер (SUPER+E) |
| `menu` | `string` | `"wofi --show drun"` | Меню (зарезервовано) |
| `browser` | `string` | `"chromium"` | Браузер (SUPER+W) |
| `cursorTheme` | `string` | `"Capitaine Cursors (Gruvbox)"` | Тема курсора; `""` — не встановлювати |
| `cursorSize` | `number` | `24` | Розмір курсора |
| `autostart` | `array` | `[]` | Автостарти при старті Hyprland |
| `autostart[].command` | `string` | — | Команда |
| `autostart[].workspace` | `number?` | `null` | Робочий стіл (`[workspace N silent]`) |
| `devices` | `array` | `[]` | Налаштування пристроїв введення |
| `devices[].name` | `string` | — | Ім'я пристрою (з `hyprctl devices`) |
| `devices[].sensitivity` | `number?` | — | Чутливість миші |
| `devices[].accel_profile` | `string?` | — | `flat`/`adaptive` |
| `devices[].scroll_factor` | `number?` | — | Множник скролу |

Примітка: `quickshell` запускається завжди, незалежно від `autostart`
(інфраструктура шела, не користувацький вибір).

---

## Hyprland: `.conf` файли

Формат — стандартний Hyprland `.conf`:
- `hyprsunset.conf`: температура фільтра синього
- `hyprtoolkit.conf`: тема hyprlauncher (кольори, шрифт, заокруглення)

---

## Quickshell: scripts/.env

HoYoLAB-креди для Genshin-віджета. Копіюється з `.env.example`:
`GENSHIN_COOKIE`, `GENSHIN_UID`, `GENSHIN_SERVER`, `GENSHIN_ACT_ID`.
Значення-заглушки (`your_...`) детектуються `selfshell doctor`.
Файл у `.gitignore` — не потрапляє в репозиторій.

---

## Hyprland: Lua-модулі (`modules/*.lua`)

Lua-скрипти, що викликають глобальні функції `hl.*`:

| Функція | Призначення |
|---------|-------------|
| `hl.curve()` | Визначення Bezier-кривої |
| `hl.animation()` | Налаштування анімації |
| `hl.bind()` | Гаряча клавіша |
| `hl.config()` | Блок конфігурації (general, decoration, misc) |
| `hl.device()` | Налаштування пристрою введення |
| `hl.env()` | Змінна оточення |
| `hl.exec_cmd()` | Виконання команди |
| `hl.on()` | Обробник події |
| `hl.window_rule()` | Правило для вікон |
| `hl.dsp.*` | Дії (exec_cmd, window.close, window.move, focus) |

---

## Fish: `config.fish`

Стандартний Fish-скрипт. Виконується при старті shell.

---

## Kitty: `kitty.conf`

Стандартний формат Kitty:
```
shell fish
map ctrl+c copy_and_clear_or_interrupt
...
include current-theme.conf
```

---

## Starship: `config.toml`

Стандартний TOML-формат Starship. Палітра `tokyonight` оновлюється
автоматично через `update-palette.py`:

```toml
[palettes.tokyonight]
background = "#2e3132"
foreground = "#dee3e5"
...
```

---

## Yazi: `*.toml`

Стандартний TOML-формат Yazi:
- `yazi.toml`: секції `[manager]`, `[preview]`, `[opener]`, `[open]`, `[tasks]`, `[plugin]`, `[input]`, `[confirm]`, `[pick]`, `[which]`
- `keymap.toml`: секції `[manager]`, `[tasks]`, `[spot]`, `[pick]`, `[input]`, `[confirm]`, `[cmp]`, `[help]`
- `theme.toml`: секції `[flavor]`, `[icon]`

---

## Fastfetch: `config.jsonc`

Стандартний JSON з коментарями. Секції: `logo`, `display`, `modules`.
