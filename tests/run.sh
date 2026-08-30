#!/usr/bin/env bash
# ============================================================
# tests/run.sh — локальний харнес тестів репозиторію.
# Запуск: bash tests/run.sh (з будь-якої теки).
# Інструменти, яких немає в системі, пропускаються з позначкою SKIP.
# ============================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
total=0

run() { # run <ім'я> <команда...>
  local name="$1"; shift
  total=$((total + 1))
  echo
  echo "== $name =="
  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    fail=1
  fi
}

skip() { # skip <ім'я> <причина>
  echo "SKIP: $1 ($2)"
  total=$((total + 1))
}

have() { command -v "$1" >/dev/null 2>&1; }

echo "SELFshell test harness ($ROOT)"

# --- Shell-синтаксис ---
run "bash -n (install.sh, scripts)" bash -c \
  'ok=0; for f in install.sh quickshell/scripts/selfshell quickshell/scripts/update-palette.sh tests/install_test.sh; do bash -n "$f" && ok=$((ok+1)); done; [ "$ok" -eq 4 ]'

# --- Інсталер: функціональні тести хелперів ---
run "install.sh function tests" bash tests/install_test.sh

# --- Lua — unit-тести json.lua та smoke env/rules ---
if have luajit; then
  run "lua: json.lua unit tests" luajit tests/lua/json_test.lua "$ROOT"
  run "lua: env+rules smoke" luajit tests/lua/env_rules_test.lua "$ROOT"
  run "lua: binds unit test" luajit tests/lua/binds_test.lua "$ROOT"
else
  skip "lua tests" "luajit not installed"
fi

# --- Фікстура фейкового upower: контракт виводу, який парсить BatteryWidget ---
run "fake upower fixture" bash -c '
  export FAKE_BATTERY_PCT=12 FAKE_BATTERY_STATE=discharging
  [ "$(bash tests/fake_upower.sh -e)" = "/org/freedesktop/UPower/devices/battery_BAT0" ] || exit 1
  out="$(bash tests/fake_upower.sh -i)"
  echo "$out" | grep -qE "^[[:space:]]*state[[:space:]]*:[[:space:]]*discharging[[:space:]]*$" || exit 1
  line="$(echo "$out" | grep -E "^[[:space:]]*percentage" | head -1)"
  python3 -c "import re,sys; m=re.match(r\"^\s*percentage\s*:\s*(\d+)%\", sys.argv[1]); assert m and int(m.group(1)) == 12, sys.argv[1]" "$line" || exit 1
  export FAKE_BATTERY_STATE=charging
  bash tests/fake_upower.sh -i | grep -q "state:[[:space:]]*charging" || exit 1
'

# --- Python — unittest (genshin, update-palette) ---
if python3 -c "import requests, dotenv" >/dev/null 2>&1; then
  run "python unit tests" python3 -m unittest discover -s tests/python
else
  skip "python unit tests" "python3-requests / python3-dotenv missing"
fi

# --- Python-перевірки конфігів та документації ---
run "config schema check" python3 tests/check_config_schema.py
run "markdown links check" python3 tests/check_md_links.py
run "banner check (quickshell)" python3 tests/check_banner.py

# --- Канонічний регістр URL репозиторію (TripShuti/SELFshell) ---
# Нижній регістр імені репо працює лише через редирект GitHub —
# у скриптах (selfshell REPO_URL, docs, README) має бути канонічний.
run "canonical repo URL" bash -c \
  '! grep -rn "TripShuti/[s]elfshell" . --exclude-dir=.git --exclude-dir=__pycache__ 2>/dev/null'

# --- Fish-синтаксис ---
if have fish; then
  run "fish syntax" fish -n fish/config.fish fish/conf.d/*.fish
else
  skip "fish syntax" "fish not installed"
fi

# --- Shellcheck (якщо встановлено) ---
if have shellcheck; then
  run "shellcheck" bash -c 'shellcheck install.sh quickshell/scripts/selfshell quickshell/scripts/update-palette.sh'
else
  skip "shellcheck" "shellcheck not installed"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAILED ($total steps)"
  exit 1
fi
echo "RESULT: all $total steps passed"