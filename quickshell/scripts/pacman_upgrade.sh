#!/usr/bin/env bash
# ============================================================
# quickshell/scripts/pacman_upgrade.sh — повне оновлення системи в терміналі із сигналом завершення
# ============================================================
# USAGE: pacman_upgrade.sh <sentinel-file>
# Запускається з PacmanService через `kitty -e ...`: той самий хелпер, що
# знайшов pacman_updates.py (yay/paru вміють і репозиторії, і AUR одним
# проходом), інакше `sudo pacman -Syu` — пароль питає sudo в цьому ж вікні.
# По завершенні exit-код пишеться в sentinel-файл (його опитує сервіс і
# одразу перечитує список), вікно тримається паузою, щоб було видно підсумок.
set -u

sentinel="${1:?usage: pacman_upgrade.sh <sentinel-file>}"
mkdir -p "$(dirname "$sentinel")"
# старі сигнали затираємо, щоб сервіс не сплутав з поточним запуском
rm -f "$(dirname "$sentinel")"/done-*

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

printf '%s\n' "$code" > "$sentinel"

echo
read -rp "Done (exit $code). Press Enter to close... " _ || true
