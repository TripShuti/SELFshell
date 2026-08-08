#!/usr/bin/env bash
# ============================================================
# tests/install_test.sh — функціональні тести хелперів install.sh
# (backup_and_replace, restore_backups, confirm, run_retry) шляхом
# витягування реальних функцій з файлу. Без root, без мережі.
# Запуск: bash tests/install_test.sh
# ============================================================
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELLSH="$ROOT/install.sh"
SANDBOX="$(mktemp -d /tmp/install-test.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/home" "$SANDBOX/repo/quickshell/scripts" "$SANDBOX/repo/hypr"
echo marker > "$SANDBOX/repo/quickshell/marker"
touch "$SANDBOX/repo/quickshell/scripts/.env.example"

extract() { # extract function <name> from install.sh to stdout
  awk -v name="$1" '
    $0 ~ "^" name "()" { on=1; print; next }
    on { print }
    on && /^}/ { exit }
  ' "$SHELLSH"
}

export SB_HOME="$SANDBOX/home"
export SB_REPO="$SANDBOX/repo"
export SB_TS="20260808-120000"

TMPH="$(mktemp)"
{
  echo 'set -eo pipefail'
  echo 'HOME="$SB_HOME"'
  echo 'REPO_DIR="$SB_REPO"'
  echo 'ts="$SB_TS"'
  printf '%s\n' \
    'ASSUME_YES=""' \
    'info() { echo "[i] $*"; }' \
    'warn() { echo "[!] $*"; }' \
    'error() { echo "[x] $*" >&2; }' \
    '_FAILED=0' '_BACKED_UP=()'
  extract backup_and_replace
  extract restore_backups
  extract confirm
  extract run_retry
  cat << 'BODY'

# --- T1: replace keeps a backup ---
mkdir -p "$HOME/target1" && echo old > "$HOME/target1/old.txt"
backup_and_replace "$HOME/target1" "$REPO_DIR/quickshell"
[ -f "$HOME/target1/marker" ] || { echo "FAIL T1: copy missing"; exit 1; }
[ -f "$HOME/target1.bak-$ts/old.txt" ] || { echo "FAIL T1: backup missing"; exit 1; }
echo "T1 replace+backup OK"

# --- T2: failure -> restore_backups puts the old config back ---
mkdir -p "$HOME/t2" && echo original > "$HOME/t2/original.txt"
backup_and_replace "$HOME/t2" "$REPO_DIR/quickshell"
rm -rf "$HOME/t2"                      # simulated disaster
restore_backups
[ -f "$HOME/t2/original.txt" ] || { echo "FAIL T2: rollback did not restore"; exit 1; }
echo "T2 rollback OK"

# T3: prompts don't abort on EOF (CI), defaults used
if confirm "Q with default y" y </dev/null; then :; else echo "FAIL T3a"; exit 1; fi
if confirm "Q with default n" n </dev/null; then echo "FAIL T3b"; exit 1; fi
echo "T3 EOF defaults OK"

# T4: manual stdin answers
echo y | confirm "Q" n   || { echo "FAIL T4a"; exit 1; }
echo n | confirm "Q" y && { echo "FAIL T4b"; exit 1; }
echo "T4 interactive OK"

# T5: --yes/--no modes
ASSUME_YES="y"; confirm "Q" n && echo "  yes-mode OK"
ASSUME_YES="n"; confirm "Q" y && { echo "FAIL T5b"; exit 1; }
echo "T5 modes OK"

# T6: run_retry success after failures (назва лічильника не конфліктує з локальною змінною)
attempts=0
fails_twice() { attempts=$((attempts+1)); [ "$attempts" -ge 3 ]; }
run_retry 3 fails_twice || { echo "FAIL T6"; exit 1; }
[ "$attempts" -eq 3 ] || { echo "FAIL T6 count: $attempts"; exit 1; }
echo "T6 retry OK (attempts: $attempts)"

# T7: run_retry exhausts
attempts=0
never() { attempts=$((attempts+1)); return 1; }
if run_retry 2 never; then echo "FAIL T7"; exit 1; fi
[ "$attempts" -eq 2 ] || { echo "FAIL T7 count"; exit 1; }
echo "T7 retry exhaustion OK"

# T8: missing parent dir (fresh user/chroot, ~/.config не існує) — створюється
if [ -e "$HOME/.config" ]; then echo "FAIL T8: sandbox .config already exists"; exit 1; fi
backup_and_replace "$HOME/.config/quickshell" "$REPO_DIR/quickshell"
[ -f "$HOME/.config/quickshell/marker" ] || { echo "FAIL T8: copy missing"; exit 1; }
echo "T8 missing parent OK"

echo "ALL INSTALL-SH FUNCTION TESTS PASSED"
BODY
} > "$TMPH"
bash -u "$TMPH"
rm -f "$TMPH"