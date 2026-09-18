#!/bin/bash
# ============================================================
# quickshell/scripts/update-palette.sh — генерує палітру з шпалери через matugen + оновлює palette.json, сповіщає quickshell через IPC
# ============================================================
set -euo pipefail
# --wallpaper-only: лише перемкнути шпалеру (awww + current.* + lock-кадр),
# без регенерації палітри (тема Black; обгортка update-wallpaper-only.sh)
WALLPAPER_ONLY=false
if [ "${1:-}" = "--wallpaper-only" ]; then
  WALLPAPER_ONLY=true
  shift
fi
WALLPAPER="${1:?usage: update-palette.sh [--wallpaper-only] <wallpaper>}"
if [ ! -f "$WALLPAPER" ]; then
  echo "error: wallpaper not found: $WALLPAPER" >&2
  exit 1
fi
case "${WALLPAPER,,}" in
  *.jpg|*.jpeg|*.png|*.gif) ;;
  *) echo "error: unsupported wallpaper format (jpg/png/gif expected): $WALLPAPER" >&2; exit 1 ;;
esac
DIR="$(cd "$(dirname "$0")" && pwd)"
EXT="${WALLPAPER##*.}"
EXT="${EXT,,}"
[ "$EXT" = "jpeg" ] && EXT="jpg"
WP_DIR="$HOME/.config/quickshell/wp"
mkdir -p "$WP_DIR"
# Паралельні `wallpaper set` з різними EXT затирали один одному current.*:
# один процес на скрипт через lockdir
LOCKDIR="$WP_DIR/.wallpaper.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "error: another wallpaper switch is in progress" >&2
  exit 1
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT
CURRENT="$WP_DIR/current.$EXT"
LOCK_FRAME="$WP_DIR/current-lock.jpg"

# awww кешує декодовані кадри ЗА ШЛЯХОМ файлу: показуємо оригінал,
# бо current.* має щоразу той самий шлях і awww віддав би застарілий кеш
awww img "$WALLPAPER"
# awww оновлює шар асинхронно — даємо 300мс щоб Hyprland отримав новий кадр,
# інакше hyprctl reload застає стару текстуру і блюр під пігулкою лишається старим
sleep 0.35
# Після зміни шпалери Hyprland з xray-блюром може кешувати старий розмитий фон
hyprctl reload >/dev/null 2>&1 || true

cp "$WALLPAPER" "$CURRENT.tmp"
mv -f "$CURRENT.tmp" "$CURRENT"

# Статичний кадр для екрану блокування (FastBlur не рендерить анімовані
# джерела — чорний екран); [0] бере перший кадр і gif, і статики
if command -v magick >/dev/null 2>&1; then
  magick "${CURRENT}[0]" -quality 85 "$LOCK_FRAME" || true
fi

# Прибираємо застарілі current.* інших форматів
find "$WP_DIR" -maxdepth 1 -name 'current.*' \
  ! -name "current.$EXT" ! -name "current-lock.jpg" -delete 2>/dev/null || true

# Регенерація палітри — пропускаємо у wallpaper-only режимі (тема Black)
if ! $WALLPAPER_ONLY; then
  /usr/bin/python3 "$DIR/update-palette.py" "$CURRENT"

  # Перефарбовуємо живі foot-термінали без рестарту (foot перечитує colors-dark)
  pkill -USR1 -x foot 2>/dev/null || true

  # Повідомляємо quickshell про зміну палітри
  quickshell ipc call palette-reload reload 2>/dev/null || true
fi
