#!/usr/bin/env bash
# ============================================================
# install.sh — SELFshell setup for Arch Linux
#
# Installs dependencies, copies quickshell config to
# ~/.config/quickshell/, and offers to copy hypr/kitty/fish/
# yazi/starship configs with backups.
# Also offers AUR helper (yay) + greetd/greeter setup.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_CONFIG_DIR="$HOME/.config/quickshell"

# --- Packages from official Arch repos ---
PACMAN_DEPS=(
  hyprland
  quickshell
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

  # extra essentials required by configs
  hyprlock
  hypridle
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
)

info()  { echo -e "\033[1;36m[i]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[!]\033[0m $*"; }
error() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

if ! command -v pacman &>/dev/null; then
  error "pacman not found. This script is for Arch Linux only."
  exit 1
fi

# --- Step 1: pacman dependencies ---
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

# --- Enable system services (NetworkManager, Bluetooth) ---
info "Enabling and starting NetworkManager and bluetooth..."
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

sudo usermod -aG lp "$USER" 2>/dev/null || true
rfkill unblock bluetooth 2>/dev/null || true
if command -v bluetoothctl &>/dev/null; then
  if ! bluetoothctl list 2>/dev/null | grep -q .; then
    warn "No Bluetooth adapter found. This is expected in a VM."
  fi
fi
if ! systemctl is-active --quiet bluetooth.service; then
  warn "bluetooth.service failed to start. Check 'rfkill list' and linux-firmware."
  systemctl status bluetooth.service --no-pager 2>&1 || true
fi

# --- Step 2: quickshell config ---
if [ -e "$QS_CONFIG_DIR" ]; then
  warn "$QS_CONFIG_DIR already exists."
  read -rp "Overwrite? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    error "Aborted by user."
    exit 1
  fi
  rm -rf "$QS_CONFIG_DIR"
fi

mkdir -p "$QS_CONFIG_DIR"
cp -r "$REPO_DIR/quickshell/." "$QS_CONFIG_DIR"
info "Copied to $QS_CONFIG_DIR"

if [ ! -f "$QS_CONFIG_DIR/scripts/.env" ] && [ -f "$QS_CONFIG_DIR/scripts/.env.example" ]; then
  cp "$QS_CONFIG_DIR/scripts/.env.example" "$QS_CONFIG_DIR/scripts/.env"
  warn "Created scripts/.env from .env.example — fill in your HoYoLAB data if you need the Genshin widget"
  warn "(or disable enableGenshinWidget in $QS_CONFIG_DIR/Config.js)"
fi

# qs-bt-agent — BlueZ pairing agent as a systemd user service
chmod +x "$QS_CONFIG_DIR/qs-bt-agent"
mkdir -p "$HOME/.config/systemd/user"
cp "$QS_CONFIG_DIR/qs-bt-agent.service" "$HOME/.config/systemd/user/qs-bt-agent.service"
systemctl --user daemon-reload
systemctl --user enable --now qs-bt-agent.service 2>/dev/null || systemctl --user enable qs-bt-agent.service
info "qs-bt-agent installed as systemd user service (systemctl --user status qs-bt-agent)"

# --- Step 3 (optional): dotfiles — hypr/kitty/fish/yazi/starship ---
echo
read -rp "Copy hypr/kitty/fish/yazi/starship configs too? Existing ones will be backed up. [y/N] " with_dotfiles
if [[ "$with_dotfiles" =~ ^[Yy]$ ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  for dir in hypr kitty fish yazi starship; do
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
  info "Skipping hypr/kitty/fish/yazi/starship — only quickshell shell installed."
fi

# --- Step 4: AUR helper (yay) ---
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
    git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (cd /tmp/yay-build && makepkg -si --noconfirm)
    rm -rf /tmp/yay-build
    aur_helper="yay"
  fi
else
  info "Found AUR helper: $aur_helper"
fi

# --- Step 5: display manager / autostart ---
echo
info "On a bare Arch there is no display manager. After login you get a TTY."
read -rp "Set up automatic Hyprland startup? [y/N] " setup_autostart
if [[ "$setup_autostart" =~ ^[Yy]$ ]]; then
  use_greeter="n"
  if [ -n "$aur_helper" ]; then
    read -rp "Install sysc-greet-hyprland (TUI greeter via greetd)? [y/N] " use_greeter
    if [[ "$use_greeter" =~ ^[Yy]$ ]]; then
      "$aur_helper" -S sysc-greet-hyprland
      info "Package post_install set up greetd config and greeter user."
      info "Reboot to see the greeter."
    fi
  else
    warn "No AUR helper found — skipping sysc-greet-hyprland installation."
  fi

  if [[ ! "$use_greeter" =~ ^[Yy]$ ]]; then
    info "Without greeter: adding Hyprland autostart on tty1 via fish config."
    fish_config="$HOME/.config/fish/config.fish"
    if [ -f "$fish_config" ] && ! grep -q "exec Hyprland" "$fish_config"; then
      cat >> "$fish_config" << 'FISHEOF'

# Autostart Hyprland on tty1 when no display manager is present
if status is-login
    and status is-interactive
    and test -z "$WAYLAND_DISPLAY"
    and test "$XDG_VTNR" = 1
    exec Hyprland
end
FISHEOF
      info "Added to $fish_config"
    else
      info "Autostart already configured or $fish_config not found — skipping."
    fi
  fi
fi

# --- Final ---
echo
info "Done."
echo
info "Reboot now — after login you will have a fully working SELFshell desktop."
echo
info "If something is missing, check $QS_CONFIG_DIR/Config.js to tweak widgets."