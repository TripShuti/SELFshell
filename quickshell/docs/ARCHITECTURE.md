# Архітектура SELFshell

## 1. Структура репозиторія

```
selfshell/                       # корінь git-репо (клонується в ~/.config)
  ├── quickshell/                # ~/.config/quickshell/ — QML shell
  │   ├── shell.qml              # кореневий компонент
  │   ├── Bar.qml                # панель + AppConfig та вся логіка
  │   ├── VERSION                # версія проєкту (читає selfshell)
  │   ├── core/                  # інфраструктура (AppConfig, PaletteService,
  │   │                          #   IdleManager, LockContext/Surface, AnimatedPopup,
  │   │                          #   PillBar, HoverItem/Text, ToggleSwitch, ...)
  │   ├── widgets/               # 12 віджетів для панелі
  │   ├── popups/                # 13 спливаючих вікон
  │   ├── monitors/              # 2 фонових монітори (Cava, Genshin)
  │   ├── services/              # systemd-юніти та QML-сервіси (qs-bt-agent,
  │   │                          #   TrackListService, cava-vis.conf)
  │   ├── scripts/               # CLI selfshell, python/js скрипти, .env
  │   ├── data/                  # персистентні JSON (config, palette, tasks...)
  │   ├── assets/                # ресурси (звуки, іконки)
  │   ├── pam/                   # PAM-конфіг локскріна
  │   └── docs/                  # документація (не трекається в git)
  ├── hypr/                      # ~/.config/hypr/ — конфіги Hyprland
  │   ├── hyprland.lua           # кореневий Lua-конфіг
  │   ├── env.json               # користувацькі налаштування (браузер,
  │   │                          #   термінал, автостарти, девайси)
  │   ├── hyprsunset.conf        # фільтр синього
  │   ├── hyprtoolkit.conf       # тема hyprlauncher (зарезервована)
  │   └── modules/               # env, exec, general, binds, animation,
  │                              #   rules + json.lua (парсер env.json)
  ├── fish/                      # ~/.config/fish/
  │   ├── config.fish            # головний конфіг
  │   ├── conf.d/                # додаткові конфіги (палітра)
  │   └── functions/             # функції (ytdlp)
  ├── kitty/                     # ~/.config/kitty/
  ├── starship/                  # ~/.config/starship/
  ├── yazi/                      # ~/.config/yazi/
  ├── fastfetch/                 # ~/.config/fastfetch/
  ├── LICENSE
  └── install.sh                 # автоматичне встановлення
```

Кожен компонент читає конфіг із `~/.config/<компонент>/`. `install.sh`
копіює файли з відповідних піддиректорій репо в потрібні місця.

---

## 2. Hyprland — композитор

Hyprland конфігурується через Lua + `env.json` (Lua-модулі) та два
`.conf` файли.

### Lua-модулі (`hypr/modules/`)

| Модуль | Призначення |
|--------|-------------|
| `env.lua` | Читає `env.json`, віддає модулям: mainMod, термінал, браузер, курсор, автостарти, девайси |
| `json.lua` | Мінімальний JSON-парсер (без залежностей). Будь-яка помилка → `nil` |
| `exec.lua` | `XCURSOR_*` env + автозапуск: `quickshell` (завжди) та список з `env.json` |
| `general.lua` | Налаштування вікон: проміжки, border, кольори, dwindle, декор, введення; `devices[]` з `env.json` |
| `binds.lua` | Гарячі клавіші: скріншоти, лаунчер, workspace, фокус, переміщення вікон |
| `animation.lua` | Криві анімації (`wind`, `winIn`, `winOut`, `liner`) та стилі |
| `rules.lua` | Правила вікон: автоматичне перемикання розкладки, workspace для додатків |

### `env.json` — користувацькі налаштування

Файл `~/.config/hypr/env.json` (копіюється з репо). Відсутність або
пошкодження файлу → дефолти з `env.lua` (поведінка не змінюється).
Схема: `mod`, `terminal`, `fileManager`, `menu`, `browser`,
`cursorTheme`, `cursorSize`, `autostart[]` (`command`, `workspace`?),
`devices[]` (`name`, `sensitivity`, `accel_profile`, `scroll_factor`).
Детальніше — у [CONFIG_FORMAT.md](CONFIG_FORMAT.md).

### `.conf` файли

| Файл | Призначення |
|------|-------------|
| `hyprsunset.conf` | Фільтр синього світла |
| `hyprtoolkit.conf` | Тема для hyprlauncher (зарезервована — лаунчер тепер QML) |

> Локскрін (hyprlock) та idle (hypridle) замінені на QML: `LockContext`/
> `LockSurface` та `IdleManager` у quickshell (див. §9.6–9.7).

---

## 3. Fish shell — оболонка

| Файл | Призначення |
|------|-------------|
| `config.fish` | Запускає `fastfetch` при вітанні, ініціалізує Starship |
| `conf.d/99-palette.fish` | Кольори термінала, згенеровані `update-palette.py` |
| `functions/ytdlp.fish` | Обгортка `yt-dlp` для завантаження mp3 |

---

## 4. Kitty — термінал

`kitty.conf` — основний конфіг: shell fish, Ctrl+C/V, тема Gruvbox Dark через
`current-theme.conf` (автогенерується `update-palette.py`).

---

## 5. Starship — промпт

`config.toml` — кастомний промпт: username@hostname, директорія, git, мови,
час. Палітра `tokyonight` оновлюється `update-palette.py`.

---

## 6. Yazi — файловий менеджер

| Файл | Призначення |
|------|-------------|
| `yazi.toml` | Основний конфіг: віджети, відкривачі, плагіни, прев'юери |
| `keymap.toml` | Клавіатурні біндинги (VI-подібні) |
| `theme.toml` | Тема (згенерована `update-palette.py`) |
| `package.toml` | Залежності: сторонні теми (lain, kanagawa, ayu-dark, everforest-medium) |

---

## 7. Fastfetch — системна інформація

`config.jsonc` — виводить лого Arch, ОС, ядро, хост, пакети, shell, WM,
uptime, пам'ять, диск. Кожен модуль має свій колір ключа.

---

## 8. install.sh — автоматичне встановлення

Сценарій:
1. Встановлює пакети з `PACMAN_DEPS` (hyprland, quickshell, kitty, fish, starship, yazi та їхні залежності)
2. Копіює `quickshell/` в `~/.config/quickshell/`, створює `.env` з `.env.example`
3. Встановлює `qs-bt-agent` як systemd user-сервіс
4. Встановлює CLI `selfshell` (chmod + symlink у `~/.local/bin/`)
5. Пропонує скопіювати hypr/kitty/fish/yazi/starship (з бекапом старих)
6. Пропонує встановити AUR helper (yay) та sysc-greet-hyprland
7. Налаштовує автозапуск Hyprland на tty1

---

## 9. Архітектура quickshell (QML shell)

*Нижче — архітектура QML-оболонки, яка є основною частиною проєкту.*

### Дерево компонентів

```
ShellRoot (shell.qml)
  └── Bar (на кожен монітор)
      ├── leftPill          ← контейнер-градієнт
      │   └── RowLayout → Repeater → Loader[widgetComponents[name]] → Widget
      ├── centerPill
      │   └── RowLayout → Repeater → Loader[widgetComponents[name]] → Widget
      └── rightPill
          └── RowLayout → Repeater → Loader[widgetComponents[name]] → Widget
```

### 9.1. Чому не статичні QML-елементи?
Віджети завантажуються динамічно через `Loader` + мапу `widgetComponents`
(у Bar.qml). Це дозволяє:
- змінювати порядок і склад пігулок без правки коду (через Settings)
- вмикати/вимикати віджети без перезапуску shell

Ключовий нюанс: `Layout.fillHeight` треба ставити на сам `Loader`, а не на
компонент всередині. Якщо цього не зробити — деякі віджети, які читають
`parent.height` (Mpris, Audio та інші), отримають 0×0 через замкнене коло
біндингів (Loader → item → parent.height → Loader). Функція
`widgetNeedsFillHeight()` (у Bar.qml) визначає, які віджети цього
потребують.

---

### 9.2. AppConfig — модель даних

`AppConfig` (core/AppConfig.qml) — єдиний QtObject, що містить:
- **стан (Enabled)** — `launcherEnabled`, `workspacesEnabled`, тощо
- **порядок (Order)** — три масиви `leftOrder`, `centerOrder`, `rightOrder`

### Приналежність до пігулки
Окремої властивості `pill` чи `xPill` немає. Приналежність визначається
виключно тим, у якому з трьох масивів (`leftOrder`/`centerOrder`/`rightOrder`)
знаходиться ім'я віджета. Функція `pillOf()` (в AppConfig.qml) шукає ім'я в усіх
трьох; якщо не знайшло — фолбечиться на `"left"`.

### `activeWidgets` — реєстр живих інстансів
Коли `Loader` завантажує віджет, він викликає `registerActive(name, item)`
(у Bar.qml). Це робить **нове призначення цілого об'єкта**, а не мутацію
ключа, тому що QML-біндинги (як `Connections` для onClicked та `anchorItem`
для попапів) не реагують на мутацію ключа всередині JS-об'єкта — їм потрібен
новий об'єкт-посилання.

### Persistence: читання/запис data/config.json

Налаштування зберігаються в `data/config.json` (формат JSON).
За читання/запис відповідає `AppConfig.qml` через `Quickshell.Io.FileView`:

```json
{
  "launcherEnabled": true,
  "workspacesEnabled": true,
  "leftOrder": ["launcher", "workspaces", "mpris"],
  "centerOrder": ["clock", "timer", "genshin"],
  "rightOrder": ["tray", "sep-0", "bt", "net", "sep-1", "keyboard", "audio", "control"]
}
```

**Читання** — `Component.onCompleted` у AppConfig.qml парсить `configFile.text()`
через `JSON.parse()` і застосовує значення через `loadFromJson()`.

**Запис** — `saveToFile()` серіалізує поточний стан у JSON і викликає
`configFile.setText()`. FileView автоматично записує зміни на диск.

Переваги JSON-формату:
- стандартний парсер — жодних regex-костилів
- зворотна сумісність: незнайомі поля просто ігноруються
- зміни застосовуються негайно, без перезапуску shell

---

### 9.3. Monitors — фоновий збір даних

Monitors (CavaMonitor, GenshinMonitor) — це QML-компоненти, які:
- запускають фоновий процес (cava, python-скрипт)
- постійно оновлюють властивості (bars, resinText)
- ці властивості зв'язані з віджетами через біндинги в Bar.qml

Гейт через `Config`: кожен монітор має властивість `monitorEnabled`, яка
читає відповідний `appConfig.*Enabled`. Якщо віджет вимкнено — монітор не
спавнить фоновий процес (`cavaProcess.running = false`, вимикає таймери).
Таким чином непотрібні процеси не висять у пам'яті.

```
GenshinMonitor (у GenshinMonitor.qml)
  ├── mainTimer      — щохвилини: локальний обрахунок смоли, daily sync check
  ├── highResinTimer — кожні 8 хв: авто-синк, коли смоли ≥ 198
  ├── syncProc       — Process: викликає genshin_stats.py sync
  └── manualProc     — Process: ручний рефреш з кулдауном 30 с
```

Пороги (у GenshinMonitor.qml): `resinClass = "critical"` при смолі ≥ 190
(пульсуюча підсвітка у віджеті), авто-синк вмикається при ≥ 198.
Після rate-limit від HoYoLAB `genshin_stats.py` ставить backoff на 15 хв.

CavaMonitor аналогічно: запускає `cava -p cava-vis.conf`, парсить числа,
експоненційно згладжує, виставляє `bars`.

---

### 9.4. Popups — спливаючі вікна

Всі попапи наслідують `AnimatedPopup.qml` — базовий компонент з:
- анімацією появи (scale + fade + slide)
- анімацією закриття (зворотний процес)
- спільним фоном (градієнт + обводка + підсвітка)
- обробкою Escape

Ключовий архітектурний момент — **outerGlow** (AnimatedPopup.qml:47–55):
раніше glow виходив за межі container через `anchors.margins: -3`, але
PopupWindow (Wayland-поверхня) має розмір рівно container-а. Це означало,
що зовнішні пікселі glow обрізались поверхнею під прямим кутом, лишаючи
гострі клинки заокругленого сяйва по кутах попапу. Виправлено: glow тепер
всередині container, `anchors.fill: container`.

Кожен попап прив'язаний до віджета через `anchorItem` — наприклад,
`calendarPopup.anchorItem = root.clockWidget`. Попап з'являється під/над
відповідним віджетом. Зв'язок реалізовано через `Connections` на клік.

---

### 9.5. Settings — drag-and-drop

SettingsPopup дозволяє:
- вмикати/вимикати віджети (чекбокси)
- перетягувати віджети між пігулками (drag-and-drop)
- змінювати порядок всередині пігулки

Реалізація:
- dragged-елемент **не фільтрується** з моделі `Repeater`, а лишається на
  місці (його візуальний стан контролюється через прозорість/висоту)
- проміжні `readonly property` замінені на функції для уникнення
  binding-loop (QML не завжди коректно обчислює залежності через
  проміжні властивості в такій конфігурації)
- "pill" у контексті Settings — це drag-and-drop zone (left/center/right)

---

### 9.6. Lockscreen — заміна hyprlock

QML-локскрін на основі `WlSessionLock` + `LockContext` (PamContext).
Вбудований безпосередньо в `shell.qml` — один процес. IPC через `IpcHandler` для команд `lock` / `toggle` (викликаються через `qs ipc call lockscreen ...` з `binds.lua` та кнопок живлення).

```
╔═══════════════════════════════════════════════╗
║           shell.qml (один процес)             ║
║  ShellRoot                                    ║
║    ├── LockContext       ← PAM (PamContext)   ║
║    ├── WlSessionLock                          ║
║    │   └── LockSurface (× монітори)           ║
║    ├── IdleManager       ← 3 IdleMonitor      ║
║    ├── IpcHandler "lockscreen"                ║
║    ├── sleepMonitor      ← dbus-monitor +     ║
║    │                      StdioCollector      ║
║    │                      (PrepareForSleep)   ║
║    ├── suspendProc       ← Process            ║
║    ├── Connections       ← unlock→locked=false ║
║    ├── Connections       ← idle→lock/suspend   ║
║    └── Variants → Bar (× монітори)            ║
╚═══════════════════════════════════════════════╝
```

`WlSessionLock.locked` прив'язаний до `LockContext.locked`:
- `LockContext.locked = true` → композитор ховає Bar, показує LockSurface
- `LockContext.locked = false` → композитор ховає LockSurface, показує Bar
- Unlock: LockContext.onUnlocked → `locked = false`

Один процес вирішує проблему зникнення локскріна після S3 resume:
shell.qml заморожується/розморожується разом з системою, WlSessionLock
залишається `locked: true`.

#### Чому WlSessionLock, а не PanelWindow

`PanelWindow` — layer-shell панель, не дає fail-secure гарантій.
`WlSessionLock` реалізує `ext-session-lock-v1`: композитор гарантує,
що поверхня заблокована, і не розблоковує при краху quickshell.
При краху quickshell композитор показує суцільний колір — fail-secure.

#### PAM без пароля в argv

`LockContext.qml` використовує `Quickshell.Services.Pam.PamContext`
замість зовнішнього `pamtester` — пароль передається напряму в PAM
у пам'яті процесу, а не через аргументи командного рядка
(які видно іншим процесам через `/proc/<pid>/cmdline`).

Конфіг PAM — локальний файл `pam/password.conf` у директорії
quickshell (`auth required pam_unix.so`), не `/etc/pam.d/`.

#### Багатомоніторний фокус

`LockSurface` містить `MouseArea` на всю площу, яка викликає
`passwordInput.forceActiveFocus()` при кліку. Це необхідно, тому що
на деяких композиторах фокус на полі пароля губиться при перемиканні
моніторів.

#### fail-secure

Якщо shell.qml (один процес) впаде під час блокування, `ext-session-lock-v1`
зобов'язує композитор показати суцільний колір (не розблоковувати сесію).
Для виходу — перемкнутись на TTY і перезапустити shell:
```sh
killall quickshell && quickshell &
```

#### Підготування до сну (logind)

`dbus-monitor` слухає сигнал `PrepareForSleep` від `org.freedesktop.login1`.
Коли logind готує систему до сну (lid close, `systemctl suspend`, кнопка
живлення), він посилає `PrepareForSleep(true)`. shell.qml ловить це через
`StdioCollector` і виставляє `lockContext.locked = true` **до** того, як
система засне. Таким чином після resume локскрін залишається активним.

```
StdioCollector ← dbus-monitor --system 'type=signal,...
              │                member=PrepareForSleep'
              │ grep --line-buffered 'boolean true'
              │
              └→ onDataChanged → lockContext.locked = true
```

Також цей механізм спрацьовує при `systemctl suspend` з термінала — тобто
**всі** шляхи до сну ведуть до попереднього локу.

---

### 9.7. IdleManager — заміна hypridle

Три рівні `IdleMonitor` замість `hypridle.conf`:

| Рівень | Таймаут | Дія |
|--------|---------|-----|
| 1 | 300 с | Сигнал `lockRequested()` → `lockContext.locked = true` |
| 2 | 360 с | `hyprctl dispatch dpms off` (з автовідновленням) |
| 3 | 900 с | Сигнал `suspendRequested()` → `lockContext.locked = true`, потім `systemctl suspend` |

`IdleManager` не знає про `lockContext`/`sessionLock` — спілкується
через сигнали. `shell.qml` підписується на них через `Connections`:

```qml
Connections {
  target: idleManager
  function onLockRequested()      { lockContext.locked = true }
  function onSuspendRequested()   {
    lockContext.locked = true      // лок перед сном
    suspendProc.command = ["systemctl", "suspend"]
    suspendProc.running = true
  }
}
```

#### Переваги перед hypridle

- Однаковий синтаксис для всіх рівнів
- Вбудований в shell — нуль окремих процесів

---

### 9.8. Bluetooth Agent

`qs-bt-agent` — окремий Python-скрипт, що реалізує BlueZ pairing agent.
Запускається як **systemd user-сервіс**, а не через Hyprland `exec-once`.

Чому окремий процес + systemd, а не exec-once:
- агент має бути запущений до того, як будь-який Bluetooth-клієнт
  спробує парування
- systemd user-сервіс гарантує автозапуск при логіні, незалежно від
  того, чи Hyprland встиг завантажитись
- якщо агент впаде — systemd перезапустить його автоматично

---

## 10. CLI `selfshell`

`scripts/selfshell` — CLI без залежностей (чистий bash). Встановлюється
`install.sh` як symlink `~/.local/bin/selfshell`. Команди:

| Команда | Що робить |
|---------|-----------|
| `ipc call <target> <fn> [args]` | Обгортка `qs ipc call` |
| `lock` / `toggle-lock` | `qs ipc call lockscreen ...` |
| `launcher` / `settings` | `qs ipc call launcher/settings toggle` |
| `palette-reload` | `qs ipc call palette-reload reload` |
| `doctor` | Діагностика: залежності, python-модулі, сесія, конфіги, сервіси, ddcutil. Exit 1 при критичних проблемах |
| `reload` | `qs kill` + `qs -d` (у цій версії quickshell `qs reload` не існує) |
| `update` | `git pull --ff-only` + `reload` |
| `version` | Версія з git tag або `VERSION` |
| `list` | `qs list` |

Шляхи резолвляться відносно самого скрипта (`readlink -f`), тому CLI
працює і з клону репо, і з `~/.config/quickshell/`.
