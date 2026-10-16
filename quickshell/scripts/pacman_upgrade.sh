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
echo "Updating official repository packages..."
sudo pacman -Syu || code=$?

# Збій AUR не блокує офіційні пакети; після помилки pacman AUR не запускаємо.
if [ "$code" -ne 0 ]; then
  echo "Official repository update failed (exit $code). AUR update skipped." >&2
elif [ -n "$helper" ]; then
  echo
  echo "Official repository update completed. Updating AUR packages..."
  "$helper" -Sua || code=$?
  if [ "$code" -ne 0 ]; then
    echo "Official repository update completed, but AUR update failed (exit $code)." >&2
  fi
fi

echo
read -rp "Done (exit $code). Press Enter to close... " _ || true
exit "$code"
