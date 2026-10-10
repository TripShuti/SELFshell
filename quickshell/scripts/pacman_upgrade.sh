#!/usr/bin/env bash
# ============================================================
# quickshell/scripts/pacman_upgrade.sh — повне оновлення системи в терміналі із сигналом завершення
# ============================================================
# Запускається в незалежному user-unit. flock захищає також ручний запуск.
set -u

runtime="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
exec {upgrade_fd}>"$runtime/selfshell-pacman.lock"
if ! flock -n "$upgrade_fd"; then
  echo "Another SELFshell upgrade is already running." >&2
  exit 1
fi

helper=""
for h in yay paru; do
  if command -v "$h" >/dev/null 2>&1; then helper="$h"; break; fi
done

code=0
if [ -n "$helper" ]; then
  "$helper" -Syu || code=$?
else
  sudo pacman -Syu || code=$?
fi

echo
read -rp "Done (exit $code). Press Enter to close... " _ || true
exit "$code"
