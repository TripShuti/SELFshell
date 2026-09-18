#!/bin/bash
# ============================================================
# quickshell/scripts/update-wallpaper-only.sh — змінює шпалеру без регенерації палітри (для теми Black)
# ============================================================
# Тонка обгортка над update-palette.sh --wallpaper-only: вся логіка
# (lockdir, current.*, awww, lock-кадр) живе там, тут лише прапор.
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "usage: update-wallpaper-only.sh <wallpaper>" >&2
  exit 1
fi
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/update-palette.sh" --wallpaper-only "$@"
