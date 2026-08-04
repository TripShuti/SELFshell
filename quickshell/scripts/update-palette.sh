#!/bin/bash
# ============================================================
# update-palette.sh — генерує палітру з шпалери через matugen
# + оновлює palette.json, сповіщає quickshell через IPC
# ============================================================
set -euo pipefail
WALLPAPER="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT="$HOME/.config/quickshell/wp/current.jpg"

cp "$WALLPAPER" "$CURRENT"
awww img "$CURRENT"

/usr/bin/python3 "$DIR/update-palette.py" "$CURRENT"

# Перефарбовуємо живі foot-термінали без рестарту (foot перечитує colors-dark)
pkill -USR1 -x foot 2>/dev/null || true

# Повідомляємо quickshell про зміну палітри
quickshell ipc call palette-reload reload 2>/dev/null || true
