#!/bin/bash
# ============================================================
# update-palette.sh — генерує палітру з шпалери через matugen
# + оновлює Palette.js, перезапускає quickshell
# ============================================================
WALLPAPER="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT="$HOME/.config/quickshell/wp/current.jpg"

cp "$WALLPAPER" "$CURRENT"
awww img "$CURRENT"

/usr/bin/python3 "$DIR/update-palette.py" "$CURRENT"

setsid bash -c "
  sleep 1.5
  killall -q quickshell
  sleep 0.5
  nohup quickshell &>/dev/null &
" &>/dev/null &

sleep 0.2
