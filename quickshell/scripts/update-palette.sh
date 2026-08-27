#!/bin/bash
# ============================================================
# update-palette.sh — генерує палітру з шпалери через matugen
# + оновлює palette.json, сповіщає quickshell через IPC
# ============================================================
set -euo pipefail
WALLPAPER="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
EXT="${WALLPAPER##*.}"
EXT="${EXT,,}"
[ "$EXT" = "jpeg" ] && EXT="jpg"
CURRENT="$HOME/.config/quickshell/wp/current.$EXT"
LOCK_FRAME="$HOME/.config/quickshell/wp/current-lock.jpg"

# awww кешує декодовані кадри ЗА ШЛЯХОМ файлу: показуємо оригінал,
# бо current.* має щоразу той самий шлях і awww віддав би застарілий кеш
awww img "$WALLPAPER"
# awww оновлює шар асинхронно — даємо 300мс щоб Hyprland отримав новий кадр,
# інакше hyprctl reload застає стару текстуру і блюр під пігулкою лишається старим
sleep 0.35
# Після зміни шпалери Hyprland з xray-блюром може кешувати старий розмитий фон
hyprctl reload >/dev/null 2>&1 || true

cp "$WALLPAPER" "$CURRENT"

# Статичний кадр для екрану блокування (FastBlur не рендерить анімовані
# джерела — чорний екран); [0] бере перший кадр і gif, і статики
if command -v magick >/dev/null 2>&1; then
  magick "${CURRENT}[0]" -quality 85 "$LOCK_FRAME" || true
fi

# Прибираємо застарілі current.* інших форматів
find "$HOME/.config/quickshell/wp" -maxdepth 1 -name 'current.*' \
  ! -name "current.$EXT" ! -name "current-lock.jpg" -delete 2>/dev/null || true

/usr/bin/python3 "$DIR/update-palette.py" "$CURRENT"

# Перефарбовуємо живі foot-термінали без рестарту (foot перечитує colors-dark)
pkill -USR1 -x foot 2>/dev/null || true

# Повідомляємо quickshell про зміну палітри
quickshell ipc call palette-reload reload 2>/dev/null || true
