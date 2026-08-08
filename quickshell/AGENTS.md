# AGENTS.md — інструкції для opencode

## Мова
- Код і коментарі — **українською**
- Документація (`docs/`, README) — **англійською** (публічне репо)
- UI-рядки (те, що бачить користувач) — англійською
- Назви змінних, функцій, компонентів — англійською

## Стиль коду
- Кожен файл має починатися з банера:
  ```
  // ============================================================
  // <шлях>/<ім'я> — короткий опис одним реченням
  // ============================================================
  ```
- Для допоміжних файлів (дані, проста конфігурація) — коротший однорядковий коментар

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

## Інше
- Не додавати emoji в код
- Не створювати нові файли без потреби — редагувати існуючі
- Не додавати README або інші документаційні файли, якщо не попросили