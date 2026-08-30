# AGENTS.md — інструкції для opencode

## Мова
- Код і коментарі — **українською** (теги `FIXME`/`TODO`/`HACK`/`NOTE` дозволені як англійський префікс, але пояснення після `—`/`:` — українською)
- Документація (`docs/`, README) — **англійською** (публічне репо)
- Тексти, які бачить користувач (UI, CLI, промпти install.sh) — англійською
- Коміт-повідомлення — **англійською за Conventional Commits** (`<type>(<scope>): <summary>`)
- Назви змінних, функцій, компонентів — англійською

## Стиль коду
- Кожен файл має починатися з банера (для файлів із shebang — одразу після `#!/...`):
  ```
  // ============================================================
  // <шлях>/<ім'я> — короткий опис одним реченням
  // ============================================================
  ```
  `<шлях>` — відносний шлях від кореня відповідного компонента (`quickshell/core/AppConfig.qml`, `hypr/modules/env.lua`, `fish/config.fish`). Маркер відповідає мові файлу: `//` для QML/JS/JSONC, `#` для Bash/Python/Fish/TOML/conf, `--` для Lua. Роздільник — 60 `=`, у 2-му рядку ем-даш `—` (U+2014), опис — одним реченням.
  Винятки:
  - чистий JSON (`*.json` — `data/config.json`, `data/palette.json`, `hypr/env.json`) — без банера через синтаксис (JSON не дозволяє коментарі);
  - генеровані файли (`fish/conf.d/99-palette.fish`, `kitty/current-theme.conf`, `yazi/theme.toml`) — короткий однорядковий коментар, мова за генератором;
  - допоміжні файли (дані, проста конфігурація) — коротший однорядковий коментар

- **Форматування (інкрементально, без масового рефактору):**
  - `import`: `Quickshell*` → `QtQuick*` → локальні (`"core"`, `"widgets"`, `"popups"` тощо). Не переставляти масово в старих файлах — дотримуватись для нового коду.
  - `property` порядок у компоненті: `id` → `required property` → `implicit*`/`property` → `signal` → `function` → діти. Змішування `signal` посеред `property` — уникати.
  - QML JS: `var` (канон для QML, function-scope), не `let`/`const` — щоб не змішувати стилі (`widgets/BluetoothWidget.qml:23` — виняток, лишити як є до наступного торкання).
  - Лапки: QML — подвійні (`"..."`), JS всередині QML — теж подвійні; одинарні лише якщо рятують екранування. Не міняти масово `'` → `"` в старих файлах.
  - Якорі: `anchors { left: ... }` vs `anchors.left:` — обидва валідні, в одному файлі тримати один стиль.
  - Відступи 2 пробіли, без trailing whitespace, без масового `qmlformat` — великий диф ламає `git blame` і ризикує binding-loop (`Bar.qml` `Layout.fillHeight` на `Loader`).

## Коли писати коментар
- Рішення неочевидне з коду (архітектурний вибір, обхід бага, компроміс)
- Є відомий workaround довкола бага фреймворка
- Формат даних не самоочевидний
- Є відома крихкість/edge case, який свідомо не вирішувався

Не писати коментар, який просто повторює назву змінної/функції.

## Структура проєкту
- `core/` — інфраструктура шела (AnimatedPopup, AppConfig, IdleManager, LockContext/Surface, Separator)
- `widgets/` — віджети панелі (LauncherWidget, ClockWidget, AudioWidget, etc.)
- `popups/` — спливаючі вікна (CalendarPopup, ControlPopup, LauncherPopup, etc.)
- `monitors/` — фонові монітори (GenshinMonitor, CavaMonitor)
- `scripts/` — допоміжні Python/shell скрипти
- `data/` — персистентні дані (config.json, calendar-tasks.json, etc.)
- `services/` — системні сервіси (qs-bt-agent, cava-vis.conf)
- `pam/` — PAM-конфіг локскріна (password.conf)
- `assets/` — ресурси (звуки, шпалери)
- `docs/` (корінь репо) — документація англійською

## Архітектура
- **Вхідна точка**: `shell.qml`
- **Головна панель**: `Bar.qml`
- **Спільний стан**: `window.appConfig` — єдиний екземпляр `core/AppConfig.qml`, створюється в `Bar.qml`. Доступний усім попапам через `window.appConfig`.
- **Комунікація попапів з панеллю**: через `window` (проброшується в `required property QtObject window`). Попапи читають `window.appConfig` для стану, `window.itemRect(item)` для позиціонування.
- **IpcHandler**: для гарячих клавіш з Hyprland (`qs ipc call <target> <action>`). Визначені в `Bar.qml` та `shell.qml`.
- **Палітра**: `data/palette.json` генерується `scripts/update-palette.sh`. Читається через `PaletteService.qml` (FileView + reactive properties). Доступна через `window.palette.xxx` або `root.palette.xxx`. Зміни підхоплюються на льоту, без рестарту.
- **Персистентність**: тільки `FileView` (Quickshell.Io). Жодних `sh -c echo`/`sh -c cat`/`Process` для читання/запису файлів.
  - `data/config.json` — налаштування панелі (через AppConfig)
  - `data/calendar-tasks.json` — задачі календаря
  - `data/control-state.json` — стан центру керування
  - `data/launcher-usage.json` — статистика лаунчера
- **Reactive pattern**: `activeWidgets` у `Bar.qml` оновлюється через `Object.assign({}, old)`, не мутацією ключа — інакше QML-біндинги на `activeWidgets[name]` не спрацьовують.

## Відомі обмеження та workaround
- **`QtObject` не приймає дочірні об'єкти**. Помилка: "Cannot assign to non-existent default property". Для контейнерів з дітьми використовувати `Item { visible: false }`.
- **z-index вкладених Pill**: діти Pill всередині `RowLayout` не можуть мати власний `z` (обмеження градієнтного фону). Якщо треба перекрити — використовувати overlay поза Layout.
- **ddcutil brightness**: через обмеження DDC/CI яскравість встановлюється покроково (sub-stepping) — `_advanceSubStep()` в `ControlPopup.qml`.

## Валідація
- `quickshell` не має `--check`. Тестувати через `quickshell kill default && timeout 5 quickshell 2>&1` (перевірити наявність "Configuration Loaded" в логах).
- Bash/Python/JSON/TOML/Lua-синтаксис перевіряє GitHub Actions (`.github/workflows/ci.yml`): `bash -n`, `py_compile`, парсинг json/toml/jsonc, `loadfile` для Lua, shellcheck, luajit-unit-тести, Python-unittest, схеми конфігів, markdown-посилання, тести інсталера (`tests/`).
- Локальний прогін усієї валідації: `bash tests/run.sh` (непотребні інструменти пропускаються).
- Системна діагностика: `selfshell doctor` (або `doctor --preboot` для pre-boot стану).

## Інше
- Не додавати emoji в код
- Не створювати нові файли без потреби — редагувати існуючі
- Не додавати README або інші документаційні файли, якщо не попросили