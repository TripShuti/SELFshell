#!/bin/bash
# ============================================================
# quickshell/scripts/update-wallpaper-only.sh — змінює шпалеру без регенерації палітри (для тем Black/White)
# ============================================================
set -euo pipefail
WALLPAPER="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
EXT="${WALLPAPER##*.}"
EXT="${EXT,,}"
[ "$EXT" = "jpeg" ] && EXT="jpg"
CURRENT="$HOME/.config/quickshell/wp/current.$EXT"
LOCK_FRAME="$HOME/.config/quickshell/wp/current-lock.jpg"

# Показуємо оригінал (awww кешує за шляхом, current.* — завжди один шлях)
awww img "$WALLPAPER"
sleep 0.35
hyprctl reload >/dev/null 2>&1 || true

cp "$WALLPAPER" "$CURRENT"

if command -v magick >/dev/null 2>&1; then
  magick "${CURRENT}[0]" -quality 85 "$LOCK_FRAME" || true
fi

find "$HOME/.config/quickshell/wp" -maxdepth 1 -name 'current.*' \
  ! -name "current.$EXT" ! -name "current-lock.jpg" -delete 2>/dev/null || true
