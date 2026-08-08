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
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_CONFIG_DIR="$HOME/.config/quickshell"

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
  networkmanager
  bluez
  bluez-utils
  python-dbus
  python-gobject
  matugen
  ttf-jetbrains-mono-nerd

  # додаткові пакунки, необхідні для конфігів
  hyprsunset
  awww
  grim
  slurp
  wl-clipboard
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

  # qt6-5compat — Qt5Compat.GraphicalEffects (блюр на екрані блокування);
  # без нього quickshell не стартує взагалі
  # greetd + greetd-tuigreet — екран входу (TUI), запускає Hyprland
  # через uwsm після логіну
  # uwsm — менеджер user-сесії, fallback без greetd
)

info()  { echo -e "\033[1;36m[i]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[!]\033[0m $*"; }
error() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

if ! command -v pacman &>/dev/null; then
  error "pacman not found. This script is for Arch Linux only."
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
  read -rp "Install via 'sudo pacman -S'? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed "${missing[@]}"
  else
    warn "Skipping dependency installation. The shell may not work."
  fi
else
  info "All pacman dependencies are already installed."
fi

# --- Увімкнення системних сервісів (NetworkManager, Bluetooth) ---
# 'enable --now' може висять: enable миттєвий (симлінк), а start без
# пристрою (Bluetooth у VM) чекає по таймауту 90-180 с. Тому start
# виконується окремо з таймаутом 30 с.
svc_start() {
  local svc="$1"
  info "Enabling $svc..."
  sudo systemctl enable "$svc" --now 2>/dev/null || sudo systemctl enable "$svc"
  if ! sudo timeout 30 systemctl start "$svc" &>/dev/null; then
    warn "$svc: start timeout/failed — check your hardware, 'systemctl status $svc'"
  fi
}

# У chroot (складання образу) systemd не може запускати сервіси — лише enable
if systemd-detect-virt -q -c; then
  warn "Chroot detected — starting services skipped (enable only)."
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
  warn "bluetooth.service failed to start. Check 'rfkill list' and linux-firmware."
  systemctl status bluetooth.service --no-pager 2>&1 || true
fi

# --- Крок 2: конфіг quickshell ---
if [ -e "$QS_CONFIG_DIR" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  warn "$QS_CONFIG_DIR already exists."
  read -rp "Back it up to $QS_CONFIG_DIR.bak-$ts and reinstall? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    error "Aborted by user."
    exit 1
  fi
  mv "$QS_CONFIG_DIR" "$QS_CONFIG_DIR.bak-$ts"
  info "Backed up to $QS_CONFIG_DIR.bak-$ts"
fi

mkdir -p "$QS_CONFIG_DIR"
cp -r "$REPO_DIR/quickshell/." "$QS_CONFIG_DIR"
info "Copied to $QS_CONFIG_DIR"

if [ ! -f "$QS_CONFIG_DIR/scripts/.env" ] && [ -f "$QS_CONFIG_DIR/scripts/.env.example" ]; then
  cp "$QS_CONFIG_DIR/scripts/.env.example" "$QS_CONFIG_DIR/scripts/.env"
  warn "Created scripts/.env from .env.example — fill in your HoYoLAB data if you need the Genshin widget"
  warn "(or disable the Genshin widget in Settings → Widgets)"
fi

# qs-bt-agent — агент парування BlueZ як systemd user-сервіс
chmod +x "$QS_CONFIG_DIR/services/qs-bt-agent"
mkdir -p "$HOME/.config/systemd/user"
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
read -rp "Copy hypr/kitty/fish/yazi/starship/fastfetch configs too? Existing ones will be backed up. [y/N] " with_dotfiles
if [[ "$with_dotfiles" =~ ^[Yy]$ ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  for dir in hypr kitty fish yazi starship fastfetch; do
    target="$HOME/.config/$dir"
    src="$REPO_DIR/$dir"
    [ -d "$src" ] || continue
    if [ -e "$target" ]; then
      backup="$target.bak-$ts"
      mv "$target" "$backup"
      warn "Existing $target backed up to $backup"
    fi
    cp -r "$src" "$target"
    info "Installed ~/.config/$dir"
  done

  if command -v ya &>/dev/null && [ -f "$HOME/.config/yazi/package.toml" ]; then
    info "Installing Yazi plugins..."
    ya pack -i 2>/dev/null || true
  fi
else
  info "Skipping hypr/kitty/fish/yazi/starship/fastfetch — only quickshell shell installed."
fi

# --- Папка для скріншотів (бінд Print у binds.lua) ---
mkdir -p "$HOME/Screenshots"

# --- Крок 4: AUR helper (yay) ---
echo
aur_helper=""
for h in yay paru; do
  command -v "$h" &>/dev/null && aur_helper="$h" && break
done

if [ -z "$aur_helper" ]; then
  info "No AUR helper (yay/paru) found."
  read -rp "Install yay from AUR? [y/N] " install_yay
  if [[ "$install_yay" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/yay-build
    git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (cd /tmp/yay-build && makepkg -si --noconfirm)
    rm -rf /tmp/yay-build
    aur_helper="yay"
  fi
else
  info "Found AUR helper: $aur_helper"
fi

# --- Крок 4.5: курсор Bibata (AUR) ---
# XCURSOR_THEME/HYPRCURSOR_THEME ставить exec.lua; тут додатково
# застосовуємо тему для GTK (gsettings) і X-додатків без env (index.theme)
CURSOR_THEME="Bibata-Modern-Classic"
if [ -n "$aur_helper" ]; then
  read -rp "Install Bibata cursor theme ($CURSOR_THEME, AUR)? [y/N] " use_cursor
  if [[ "$use_cursor" =~ ^[Yy]$ ]]; then
    "$aur_helper" -S --needed --noconfirm bibata-cursor-theme || warn "Bibata install failed — cursor stays default"
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
else
  warn "No AUR helper — cursor theme (bibata) skipped, cursor stays default."
fi

# --- Крок 5: менеджер входу (greetd+tuigreet) / автозапуск ---
echo
info "On a bare Arch there is no display manager. After login you get a TTY."
read -rp "Install greetd with the tuigreet login (TUI, starts Hyprland via uwsm)? [y/N] " use_greetd
if [[ "$use_greetd" =~ ^[Yy]$ ]]; then
  # greetd уже в PACMAN_DEPS (крок 1) — тут доставляємо лише якщо юзер пропустив крок 1
  if ! pacman -Qi greetd-tuigreet &>/dev/null; then
    sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
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
  info "greetd enabled. Reboot to see the TUI login (tuigreet)."
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
"$QS_CONFIG_DIR/scripts/selfshell" doctor --preboot || true
echo
info "Done."
echo
info "Reboot now — after login you will have a fully working SELFshell desktop."
echo
info "If something is missing, run 'selfshell doctor' or tweak widgets in Settings → Widgets."