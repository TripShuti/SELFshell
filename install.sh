#!/usr/bin/env bash
# ============================================================
# install.sh — автоматичне встановлення SELFshell для Arch
#
# Встановлює залежності, копіює конфіги quickshell у
# ~/.config/quickshell/, пропонує скопіювати hypr/kitty/fish/
# yazi/starship/fastfetch конфіги з бекапами.
# Також пропонує AUR helper (yay). Екран входу — greetd + tuigreet,
# який запускає Hyprland через uwsm після логіну
# (fallback без greetd: автозапуск Hyprland через uwsm у fish login).
# Фінал: selfshell doctor --preboot.
#
# Опції:
#   --yes / -y   — автоматично «y» на кожен промпт
#   --no / -n    — автоматично «n» на кожен промпт (нічого не встановлює
#                  поза межами дефолтів; корисний для огляду)
#   --help       — цей текст
#
# Гарантії:
#   - Якщо будь-який крок падає — всі бекапи, зняті цим запуском,
#     автоматично відновлюються (rollback), старі конфіги не губляться.
#   - Якщо ~/.config/quickshell — git-клон цього репозиторію, запуск
#     оновлює його через git pull замість перезапису (зберігаються
#     налаштування, .env та git-workflow із README).
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_CONFIG_DIR="$HOME/.config/quickshell"

# --- Режими ---
ASSUME_YES=""
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES="y" ;;
    --no|-n)  ASSUME_YES="n" ;;
    --help|-h)
      sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (see --help)" >&2
      exit 1
      ;;
  esac
done

# --- Пакети з офіційних репозиторіїв Arch ---
PACMAN_DEPS=(
  hyprland
  quickshell
  qt6-5compat
  greetd
  greetd-tuigreet
  uwsm
  kitty
  fish
  starship
  yazi
  playerctl
  cava
  swh-plugins
  networkmanager
  bluez
  bluez-utils
  python-dbus
  python-gobject
  matugen
  imagemagick
  ttf-jetbrains-mono-nerd

  # додаткові пакунки, необхідні для конфігів
  hyprsunset
  awww
  grim
  slurp
  wl-clipboard
  cliphist
  socat
  fastfetch
  yt-dlp
  libnotify
  pipewire
  wireplumber
  pipewire-pulse
  linux-firmware
  python-requests
  python-dotenv
  xdg-desktop-portal-hyprland
  ddcutil
  upower
  lxqt-policykit

  # qt6-5compat — Qt5Compat.GraphicalEffects (блюр на екрані блокування);
  # без нього quickshell не стартує взагалі
  # greetd + greetd-tuigreet — екран входу (TUI), запускає Hyprland
  # через uwsm після логіну
  # uwsm — менеджер user-сесії, fallback без greetd
)

info()  { echo -e "\033[1;36m[i]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[!]\033[0m $*"; }
error() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

# --- Промпт, стійкий до EOF: stdin-кінець (пусте, CI, `</dev/null`) не
# вбиває скрипт «set -e» — беремо відповідь за замовчуванням.
# USAGE: confirm "Question" [default]  → exit-code 0/1
confirm() {
  local question="$1" default="${2:-n}" ans suffix
  if [ "$ASSUME_YES" = "y" ]; then return 0; fi
  if [ "$ASSUME_YES" = "n" ]; then return 1; fi
  if [ "$default" = "y" ]; then suffix="Y/n"; else suffix="y/N"; fi
  read -rp "$question [$suffix] " ans || ans="$default"
  case "${ans:-$default}" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

# --- Network retry для кроків, що можуть зірватися на каналі ---
# USAGE: run_retry <n> <cmd...>
run_retry() {
  local tries="$1"; shift
  local i
  for ((i = 1; i <= tries; i++)); do
    if "$@"; then return 0; fi
    warn "Command failed (attempt $i/$tries): $*"
    [ "$i" -lt "$tries" ] && sleep 5
  done
  return 1
}

# --- Rollback: якщо будь-який крок падає (set -e → ERR), всі бекапи,
# зняті ЦИМ запуском, повертаються на місце. ---
_FAILED=0
_BACKED_UP=()   # пари "target|backup"

backup_and_replace() {
  local target="$1" src="$2"
  # Батьківська тека може бути відсутня на свіжому юзері/chroot
  # (напр. ~/.config) — без mkdir -p cp впаде через set -e
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ]; then
    local backup="$target.bak-$ts"
    mv "$target" "$backup"
    _BACKED_UP+=("$target|$backup")
    warn "Existing $target backed up to $backup"
  fi
  cp -r "$src" "$target"
}

restore_backups() {
  local entry target backup
  for entry in "${_BACKED_UP[@]}"; do
    target="${entry%%|*}"
    backup="${entry#*|}"
    if [ -e "$backup" ]; then
      rm -rf "$target" 2>/dev/null || true
      mv "$backup" "$target" 2>/dev/null || true
      warn "Restored $target from $backup"
    fi
  done
  _BACKED_UP=()
}

trap '_FAILED=1' ERR
trap '
  if [ "$_FAILED" -eq 1 ]; then
    echo
    error "Installation failed — restoring backups..."
    restore_backups
    echo
    error "Rerun the installer (it is safe to retry)."
  fi
' EXIT

if ! command -v pacman &>/dev/null; then
  error "pacman not found. This script is for Arch Linux only."
  exit 1
fi

# --- sudo перевірка: діагностуємо права на старті, а не в середині ---
if ! sudo -v 2>/dev/null; then
  error "sudo not available (user not in sudoers or no root privileges?)."
  echo
  error "Grant the current user sudo access and rerun the installer."
  exit 1
fi

# --- Крок 1: залежності pacman ---
info "Checking pacman dependencies..."
missing=()
for pkg in "${PACMAN_DEPS[@]}"; do
  pacman -Qi "$pkg" &>/dev/null || missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
  warn "Missing packages: ${missing[*]}"
  if confirm "Install via 'sudo pacman -S'?" n; then
    run_retry 3 sudo pacman -S --needed --noconfirm "${missing[@]}"
  else
    warn "Skipping dependency installation. The shell may not work."
  fi
else
  info "All pacman dependencies are already installed."
fi

# --- Увімкнення системних сервісів (NetworkManager, Bluetooth) ---
# 'enable --now' може висіти: enable миттєвий (симлінк), а start без
# пристрою (Bluetooth у VM) чекає по таймауту 90-180 с. Тому start
# виконується окремо з таймаутом 30 с.
svc_start() {
  local svc="$1"
  info "Enabling $svc..."
  sudo systemctl enable "$svc" 2>/dev/null || sudo systemctl enable "$svc"
  if ! sudo timeout 30 systemctl start "$svc" &>/dev/null; then
    warn "$svc: start timeout/failed — check your hardware, 'systemctl status $svc'"
  fi
}

# У chroot (складання образу) systemd не може запускати сервіси — лише
# enable.
if systemd-detect-virt -q -c; then
  warn "Chroot detected — service start skipped (enable only)."
  svc_start() {
    local svc="$1"
    info "Enabling $svc (chroot)..."
    sudo systemctl enable "$svc" 2>/dev/null || true
  }
fi

svc_start NetworkManager.service
svc_start bluetooth.service

sudo usermod -aG lp "$USER" 2>/dev/null || true
rfkill unblock bluetooth 2>/dev/null || true
if command -v bluetoothctl &>/dev/null; then
  if ! timeout 5 bluetoothctl list 2>/dev/null | grep -q .; then
    warn "No Bluetooth adapter found. This is expected in a VM."
  fi
fi
if ! systemctl is-active --quiet bluetooth.service; then
  warn "bluetooth.service failed to start. Check 'rfkill list' and kernel."
  systemctl status bluetooth.service --no-pager 2>&1 || true
fi

# --- Крок 2: конфіг quickshell ---
ts="$(date +%Y%m%d-%H%M%S)"

if [ -e "$QS_CONFIG_DIR" ]; then
  if [ -d "$QS_CONFIG_DIR/.git" ]; then
    # Git-клон цього репозиторію: оновлюємо через pull, а не будуємо
    # свіжу копію — інакше загине git-протокол `selfshell update` і
    # локальні налаштування.
    warn "$QS_CONFIG_DIR is a git clone of SELFshell."
    if confirm "Update it in place via 'git pull' (keeps your settings and .env)?" y; then
      if git -C "$QS_CONFIG_DIR" pull --ff-only; then
        info "Updated $QS_CONFIG_DIR via git pull."
      else
        error "git pull failed. The clone is untouched — fix your remote/branch."
        exit 1
      fi
    else
      info "Skipping the git clone update (no changes made)."
    fi
  else
    warn "$QS_CONFIG_DIR already exists (not a git clone)."
    if confirm "Back it up and reinstall with repo defaults?" n; then
      backup_and_replace "$QS_CONFIG_DIR" "$REPO_DIR/quickshell"
      info "Copied to $QS_CONFIG_DIR (backup in .bak-$ts)"
    else
      error "Aborted by user."
      exit 1
    fi
  fi
else
  backup_and_replace "$QS_CONFIG_DIR" "$REPO_DIR/quickshell"
  info "Copied to $QS_CONFIG_DIR"
fi

if [ ! -f "$QS_CONFIG_DIR/scripts/.env" ] && [ -f "$QS_CONFIG_DIR/scripts/.env.example" ]; then
  cp "$QS_CONFIG_DIR/scripts/.env.example" "$QS_CONFIG_DIR/scripts/.env"
  warn "Created scripts/.env from .env.example — fill in your HoYoLAB data if you need the Genshin widget"
  warn "(or disable the Genshin widget in Settings → Widgets)"
fi

# qs-bt-agent — агент парування BlueZ як systemd user-сервіс
chmod +x "$QS_CONFIG_DIR/services/qs-bt-agent"
mkdir -p "$HOME/.config/systemd/user"
# Старі інсталяції могли мати застарілий unit (напр. шлях без services/):
# дизаблимо перед заміною, щоб systemd не тримав кешовану версію
systemctl --user disable --now qs-bt-agent.service 2>/dev/null || true
cp "$QS_CONFIG_DIR/services/qs-bt-agent.service" "$HOME/.config/systemd/user/qs-bt-agent.service"
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
  systemctl --user daemon-reload 2>/dev/null || warn "systemctl --user daemon-reload failed — qs-bt-agent may not start"
  systemctl --user enable --now qs-bt-agent.service 2>/dev/null || systemctl --user enable qs-bt-agent.service
  info "qs-bt-agent installed as systemd user service (systemctl --user status qs-bt-agent)"
else
  warn "No user session (XDG_RUNTIME_DIR missing) — skipped qs-bt-agent enable."
  warn "After login run: systemctl --user enable --now qs-bt-agent"
fi

# --- CLI selfshell: chmod + symlink у ~/.local/bin ---
chmod +x "$QS_CONFIG_DIR/scripts/selfshell"
mkdir -p "$HOME/.local/bin"
ln -sf "$QS_CONFIG_DIR/scripts/selfshell" "$HOME/.local/bin/selfshell"
info "CLI installed: ~/.local/bin/selfshell (run 'selfshell help')"
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
  warn "$HOME/.local/bin is not in PATH — add it (e.g. in ~/.config/fish/config.fish)"
fi

# --- Крок 3 (необов'язково): dotfiles — hypr/kitty/fish/yazi/starship/fastfetch ---
echo
if confirm "Copy hypr/kitty/fish/yazi/starship/fastfetch configs too? Existing ones will be backed up." n; then
  for dir in hypr kitty fish yazi starship fastfetch; do
    target="$HOME/.config/$dir"
    src="$REPO_DIR/$dir"
    [ -d "$src" ] || continue
    backup_and_replace "$target" "$src"
    info "Installed ~/.config/$dir"
  done

  if command -v ya &>/dev/null && [ -f "$HOME/.config/yazi/package.toml" ]; then
    info "Installing Yazi plugins..."
    ya pack -i 2>/dev/null || true
  fi
else
  info "Skipping dotfiles — only the quickshell shell is installed."
fi

# --- Папка для скріншотів (бінд Print у binds.lua) ---
mkdir -p "$HOME/Screenshots"

# --- Крок 4: AUR helper (yay) ---
echo
aur_helper=""
for h in yay paru; do
  command -v "$h" &>/dev/null && aur_helper="$h" && break
done

install_yay() {
  # builddir зачищається навіть при аварії (RETURN trap функції)
  local builddir="/tmp/yay-build"
  trap 'rm -rf "$builddir"' RETURN
  rm -rf "$builddir"
  if ! run_retry 3 git clone https://aur.archlinux.org/yay.git "$builddir"; then
    error "Failed to clone yay from AUR."
    return 1
  fi
  if ! run_retry 3 sh -c "cd '$builddir' && makepkg -si --noconfirm"; then
    error "Failed building yay (makepkg)."
    return 1
  fi
  rm -rf "$builddir"
}

if [ -z "$aur_helper" ]; then
  info "No AUR helper (yay/paru) found."
  if confirm "Install yay from AUR?" n; then
    run_retry 3 sudo pacman -S --needed --noconfirm base-devel git
    install_yay
    aur_helper="yay"
  fi
else
  info "Found AUR helper: $aur_helper"
fi

# --- Крок 4.5: курсор Breeze (extra) ---
# XCURSOR_THEME/HYPRCURSOR_THEME ставить exec.lua; тут додатково
# застосовуємо тему для GTK (gsettings) і X-додатків без env (index.theme)
CURSOR_THEME="breeze_cursors"
if confirm "Install Breeze cursor theme ($CURSOR_THEME, extra)?" n; then
  if pacman -Qi "$CURSOR_THEME" &>/dev/null; then
    info "Cursor $CURSOR_THEME already installed."
  else
    sudo pacman -S --needed --noconfirm "$CURSOR_THEME" || warn "Breeze install failed — cursor stays default"
  fi
  if [ -d /usr/share/icons/"$CURSOR_THEME" ]; then
    sudo mkdir -p /usr/share/icons/default
    printf '[Icon Theme]\nInherits=%s\n' "$CURSOR_THEME" | sudo tee /usr/share/icons/default/index.theme >/dev/null
    if command -v gsettings &>/dev/null; then
      gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
    fi
    info "Cursor applied: $CURSOR_THEME, size 24"
  else
    warn "Cursor theme dir missing after install — cursor stays default"
  fi
else
  info "Cursor skipped — Hyprland will use its default cursor."
fi

# --- Крок 4.6: телефон (kcd, опційно, AUR — потребує yay/paru) ---
# kcd — Go KDE Connect daemon без KDE-стеку: батарея/ping/ring/share/notifications
# Працює з офіційним Android KDE Connect, LAN-only, без телеметрії
if [ -n "$aur_helper" ]; then
  if confirm "Install kcd for phone integration (kcd-bin, AUR, optional)?" n; then
    "$aur_helper" -S --needed --noconfirm kcd-bin || warn "kcd install failed — phone features will stay disabled (yay -S kcd-bin)"
    if command -v kcd &>/dev/null; then
      info "kcd installed: $(kcd --version 2>&1 | head -1)"
      if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now kcd 2>/dev/null || systemctl --user enable kcd 2>/dev/null || true
        info "kcd service: systemctl --user status kcd"
      else
        warn "No user session — skipped kcd enable. After login: systemctl --user enable --now kcd"
      fi
      warn "Firewall: allow 1716/udp+tcp and 1739:1764/tcp for phone discovery (ufw allow kcd or manual)"
      if confirm "Install kcd optional deps (sshfs for SFTP, wl-clipboard for clipboard, zenity for Share)?" n; then
        sudo pacman -S --needed --noconfirm sshfs wl-clipboard zenity 2>/dev/null || warn "Optional kcd deps install failed — doctor may warn (pacman -S sshfs wl-clipboard zenity)"
      fi
    fi
  else
    info "kcd skipped — phone widget will stay disabled (enable later: yay -S kcd-bin)"
  fi
else
  warn "No AUR helper — kcd skipped (install later: yay -S kcd-bin)"
fi

# --- Крок 4.7: трекер часу (selftrack, опційно, cargo) ---
# Focus-based time tracker для віджета Time Tracking (selftrackEnabled).
# Ставиться з git через cargo; демон — user-сервіс selftrack-daemon.
# Сервісний файл пишемо лише якщо його нема — юзер міг додати свої прапорці
# (наприклад --retention-days) і перезапис затре б його налаштування.
SELFTRACK_BIN=""
[ -x "$HOME/.cargo/bin/selftrack" ] && SELFTRACK_BIN="$HOME/.cargo/bin/selftrack"
command -v selftrack &>/dev/null && SELFTRACK_BIN="$(command -v selftrack)"
if [ -z "$SELFTRACK_BIN" ]; then
  if confirm "Install selftrack time tracker (cargo build from git, optional)?" n; then
    if ! command -v cargo &>/dev/null; then
      run_retry 3 sudo pacman -S --needed --noconfirm rust || warn "rust install failed — selftrack needs cargo (sudo pacman -S rust)"
    fi
    if command -v cargo &>/dev/null; then
      run_retry 3 cargo install --locked --git https://github.com/TripShuti/SELFtrack || warn "selftrack install failed — time tracking widget will show no data (cargo install --git https://github.com/TripShuti/SELFtrack)"
      [ -x "$HOME/.cargo/bin/selftrack" ] && SELFTRACK_BIN="$HOME/.cargo/bin/selftrack"
    fi
  else
    info "selftrack skipped — time tracking widget will show no data (install later: cargo install --git https://github.com/TripShuti/SELFtrack)"
  fi
else
  info "selftrack already installed: $SELFTRACK_BIN"
fi
if [ -n "$SELFTRACK_BIN" ]; then
  svc_file="$HOME/.config/systemd/user/selftrack-daemon.service"
  if [ ! -f "$svc_file" ]; then
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$svc_file" << 'SVCEOF'
[Unit]
Description=SELFTrack daemon — focus-based time tracker for Hyprland
After=graphical-session.target

[Service]
ExecStart=%h/.cargo/bin/selftrack daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SVCEOF
    info "selftrack-daemon service written: $svc_file"
  fi
  if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now selftrack-daemon 2>/dev/null || systemctl --user enable selftrack-daemon 2>/dev/null || true
    info "selftrack-daemon service: systemctl --user status selftrack-daemon"
  else
    warn "No user session — skipped selftrack-daemon enable. After login: systemctl --user enable --now selftrack-daemon"
  fi
fi

# --- Крок 5: менеджер входу (greetd+tuigreet) / автозапуск ---
echo
info "On a bare Arch there is no display manager. After login you get a TTY."
if confirm "Install greetd with the tuigreet login (TUI, starts Hyprland via uwsm)?" n; then
  # greetd уже в PACMAN_DEPS (крок 1) — тут доставляємо лише якщо юзер
  # пропустив крок 1
  if ! pacman -Qi greetd-tuigreet &>/dev/null; then
    run_retry 3 sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
  fi

  # Екран входу: greetd + tuigreet (TUI). Пакет greetd створює
  # /etc/greetd/ + config.toml, PAM та юзера "greeter" — лише перезаписуємо
  # команду сесії. mkdir -p обов'язковий: теки може не бути на свіжих
  # системах, а запис без неї вбив би скрипт через set -e
  sudo mkdir -p /etc/greetd
  printf '[terminal]\nvt = 1\n\n[default_session]\ncommand = "tuigreet --time --remember --cmd '\''/usr/bin/uwsm start hyprland.desktop'\''"\nuser = "greeter"\n' | sudo tee /etc/greetd/config.toml >/dev/null
  if ! sudo test -f /etc/greetd/config.toml; then
    error "Failed to write /etc/greetd/config.toml — manual steps:"
    error "  sudo systemctl enable --now greetd"
    exit 1
  fi
  info "greetd config written: /etc/greetd/config.toml (tuigreet + uwsm)"

  # Старий SDDM забирає alias display-manager.service — disable ПЕРЕД enable
  sudo systemctl disable --now sddm.service 2>/dev/null || true
  sudo systemctl enable greetd
  if ! sudo systemctl is-enabled greetd >/dev/null 2>&1; then
    error "greetd did not enable — manual step: sudo systemctl enable greetd"
    exit 1
  fi
  info "greetd enabled. Reboot to see the TUI login (greetd-tuigreet)."
else
  info "No greetd: adding Hyprland autostart via uwsm (fish login)."
  fish_config="$HOME/.config/fish/config.fish"
  if [ -f "$fish_config" ] && ! grep -q "uwsm start" "$fish_config"; then
    cat >> "$fish_config" << 'FISHEOF'

# Autostart Hyprland session via uwsm (no display manager)
if status is-login
    and test -z "$WAYLAND_DISPLAY"
    and test (tty) = /dev/tty1
    exec uwsm start hyprland.desktop
end
FISHEOF
    info "Added uwsm Hyprland autostart to $fish_config"
  else
    info "Autostart already configured or $fish_config not found — skipping."
  fi
fi

# --- Завершення ---
echo
info "Running final check:"
if ! "$QS_CONFIG_DIR/scripts/selfshell" doctor --preboot; then
  error "selfshell doctor --preboot reported problems. Inspect the output"
  error "above, then fix or rerun the installer (rerunning is safe)."
  exit 1
fi
echo
info "Done."
echo
info "Reboot now — after login you will have a fully working SELFshell desktop."
echo
info "If something is missing, run 'selfshell doctor' or tweak widgets in Settings → Widgets."