# Troubleshooting

> Перший крок для будь-якої проблеми — `selfshell doctor`
> (діагностика залежностей, конфігів, сервісів, обладнання).

## Hyprland: Lua-помилка при старті
**Симптом:** Hyprland запускається, але викидає помилку Lua.

**Причина:** Синтаксична помилка в одному з `hypr/modules/*.lua`.

**Рішення:**
```sh
hyprctl reload
# або перевірити синтаксис:
luac -p ~/.config/hypr/modules/*.lua
```

## Hyprland: не працюють гарячі клавіші
**Причина:** `mod` не встановлено в `hypr/env.json` (або файл
пошкоджений — тоді застосовуються дефолти з `env.lua`).

**Рішення:** Перевір `env.json`:
```sh
python3 -m json.tool ~/.config/hypr/env.json
```
Дефолт — `"mod": "SUPER"`.

## Hyprland: зникли автостарти / курсор / девайси
**Причина:** `hypr/env.json` пошкоджений — `json.lua` повертає `nil`,
`env.lua` застосовує дефолти (порожній `autostart`/`devices`).

**Рішення:** виправити JSON (підказка: `python3 -m json.tool
~/.config/hypr/env.json`) або відновити файл з репо, потім
`hyprctl reload`.

## Fish: кольори термінала не оновлюються
**Причина:** `99-palette.fish` не згенеровано або застарів.

**Рішення:**
```sh
~/.config/quickshell/scripts/update-palette.sh ~/.config/quickshell/wp/wp1.jpg
```

## Kitty: тема не застосовується
**Причина:** `current-theme.conf` не існує або не включено.

**Рішення:**
1. Переконайсь що в `kitty.conf` є `include current-theme.conf`
2. Запусти `update-palette.py`

## Yazi: зникли іконки або кольори
**Причина:** `theme.toml` або `flavors/palette.yazi/flavor.toml` застаріли.

**Рішення:** Запусти `update-palette.py`.

## Мережа не працює після install.sh
**Причина:** `NetworkManager` не enabled/запущений.

**Рішення:**
```sh
sudo systemctl enable --now NetworkManager
```

## Bluetooth не парується
**Причина:** `qs-bt-agent` не запущений. Це окремий процес (systemd user-сервіс),
а не частина quickshell.

**Рішення:**
```sh
systemctl --user enable --now qs-bt-agent
```

Якщо сервіс не встановлено — переконайся, що `qs-bt-agent` скопійовано в
`~/.local/bin/` або іншу директорію з `PATH`, і юніт лежить у
`~/.config/systemd/user/`.

## Гострі кути на попапах (обрізане сяйво)
**Симптом:** у кутках попапу видно гострі "клини" замість рівного заокруглення.

**Причина:** раніше `outerGlow` виходив на `-3px` за межі `container` через
`anchors.margins: -3`, але Wayland-поверхня (`PopupWindow`) має розмір рівно
`container`-а — зайві пікселі обрізались поверхнею під прямим кутом.

**Рішення:** виправлено в `AnimatedPopup.qml` — `outerGlow` тепер
використовує `anchors.fill: container`, без виходу за межі.

## Settings "поїхали" (контент не влазить)
**Симптом:** вміст Settings вилазить за межі попапу, частина елементів
недоступна.

**Причина:** була фіксована `implicitHeight`, яка не враховувала реальну
висоту контенту (особливо при великій кількості віджетів у Pool).

**Рішення:** замінено на `implicitHeight: contentColumn.implicitHeight + 30` —
автоматично підлаштовується під вміст.

## config.json скинувся на дефолти
**Симптом:** після оновлення quickshell порядок віджетів і ввімкнення
скинулись до заводських.

**Причина:** пошкоджений або порожній `data/config.json`. Якщо файл не
парситься — AppConfig застосовує фабричні дефолти.

**Рішення:** перевір синтаксис `data/config.json` через `python3 -m json.tool data/config.json`.
Якщо файл пошкоджено — відновити з резервної копії або налаштувати заново
через Settings в інтерфейсі.

## Genshin Impact: rate limit (помилка 502)
**Симптом:** GenshinWidget показує "Wait" або "Rate Limit", дані не
оновлюються.

**Причина:** HoYoLAB API обмежує частоту запитів. Після отримання 502
`genshin_stats.py` встановлює backoff на 15 хв.

**Рішення:** просто зачекати. Дані беруться з локального кешу (`estimate_local`
— обрахунок смоли на основі часу з останнього успішного синку). За 15 хв
все відновиться автоматично.

## quickshell не запускається / падає
**Рішення:**
```sh
selfshell reload       # перезапуск (qs kill + qs -d)
qs log                 # логи інстанса
```
Якщо шелл впав під час блокування — композитор показує суцільний колір
(fail-secure). Для виходу: перемкнутись на TTY і перезапустити:
```sh
killall quickshell && quickshell &
```

## quickshell не бачить зміни у config.json
**Симптом:** вручну змінив `data/config.json`, але панель не оновилась.

**Рішення:** `selfshell reload`. (FileView-зміни з UI застосовуються
негайно; ручні правки файлу — після перезапуску.)
