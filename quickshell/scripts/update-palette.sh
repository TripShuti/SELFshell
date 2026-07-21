#!/bin/bash
WALLPAPER="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"

awww img "$WALLPAPER"

/usr/bin/python3 "$DIR/update-palette.py" "$WALLPAPER"

setsid bash -c "
  sleep 1.5
  killall -q quickshell
  sleep 0.5
  nohup quickshell &>/dev/null &
" &>/dev/null &

sleep 0.2
