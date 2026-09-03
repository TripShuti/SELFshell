#!/bin/bash
# ============================================================
# quickshell/scripts/update-wallpaper-only.sh — змінює шпалеру без регенерації палітри (для тем Black/White)
# ============================================================
set -euo pipefail
WALLPAPER="${1:?usage: update-wallpaper-only.sh <wallpaper>}"
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
CURRENT="$WP_DIR/current.$EXT"
LOCK_FRAME="$WP_DIR/current-lock.jpg"

# Показуємо оригінал (awww кешує за шляхом, current.* — завжди один шлях)
awww img "$WALLPAPER"
sleep 0.35
hyprctl reload >/dev/null 2>&1 || true

cp "$WALLPAPER" "$CURRENT"

if command -v magick >/dev/null 2>&1; then
  magick "${CURRENT}[0]" -quality 85 "$LOCK_FRAME" || true
fi

find "$WP_DIR" -maxdepth 1 -name 'current.*' \
  ! -name "current.$EXT" ! -name "current-lock.jpg" -delete 2>/dev/null || true
