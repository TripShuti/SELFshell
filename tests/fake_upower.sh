#!/usr/bin/env bash
# ============================================================
# tests/fake_upower.sh — симулятор батареї для тестів BatteryWidget.
# Підставляється в PATH замість справжнього `upower`:
#   PATH="<ця тека>:...:$PATH" quickshell ...
# Параметри: FAKE_BATTERY_PCT (0-100), FAKE_BATTERY_STATE
# (discharging/charging/full). Формат виводу — як у справжнього
# `upower -i` (рядки "key: value"), які парсить BatteryWidget.
# ============================================================
set -eu

DEV="/org/freedesktop/UPower/devices/battery_BAT0"
PCT="${FAKE_BATTERY_PCT:-100}"
STATE="${FAKE_BATTERY_STATE:-full}"

case "${1:-}" in
  -e)
    echo "$DEV"
    ;;
  -i)
    printf '  native-path:          BAT0\n'
    printf '  battery:              yes\n'
    printf '  state:                %s\n' "$STATE"
    printf '  percentage:           %d%%\n' "$PCT"
    ;;
  *)
    exit 0
    ;;
esac