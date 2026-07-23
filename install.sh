#!/usr/bin/env bash
# ============================================================
# install.sh — встановлення SELFshell на Arch Linux
#
# За замовчуванням: ставить залежності через pacman + кладе
# quickshell-конфіг в ІМЕНОВАНИЙ конфіг (~/.config/quickshell/SELFshell),
# а НЕ в базовий ~/.config/quickshell/ — щоб не конфліктувати з
# уже наявним у людини шелом. Ethernet/hypr/kitty/fish/yazi/starship
# конфіги копіюються тільки за окремим підтвердженням і з бекапом.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_NAME="SELFshell"
QS_CONFIG_DIR="$HOME/.config/quickshell/$SHELL_NAME"

# --- Пакети з офіційних репозиторіїв Arch (extra/core), без AUR ---
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
)

info()  { echo -e "\033[1;36m[i]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[!]\033[0m $*"; }
error() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

if ! command -v pacman &>/dev/null; then
  error "pacman не знайдено. Цей скрипт розрахований тільки на Arch Linux (і похідні на pacman)."
  exit 1
fi

# --- Крок 1: перевірка залежностей ---
info "Перевіряю залежності через pacman..."
missing=()
for pkg in "${PACMAN_DEPS[@]}"; do
  pacman -Qi "$pkg" &>/dev/null || missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
  warn "Бракує пакетів: ${missing[*]}"
  read -rp "Встановити їх через 'sudo pacman -S'? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed "${missing[@]}"
  else
    warn "Пропускаю встановлення залежностей. Шел може не запуститись без них."
  fi
else
  info "Усі pacman-залежності вже встановлені."
fi

# Пакет встановлено — це не означає, що демон запущений. Без цього
# кроку NetManager/BtManager в шелі будуть порожні навіть на щойно
# встановленій системі.
info "Вмикаю та запускаю NetworkManager і bluetooth..."
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

# --- Крок 2: named quickshell config (безпечно, нічого не перезаписує) ---
if [ -e "$QS_CONFIG_DIR" ]; then
  warn "$QS_CONFIG_DIR вже існує."
  read -rp "Перезаписати? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    error "Перервано користувачем."
    exit 1
  fi
  rm -rf "$QS_CONFIG_DIR"
fi

mkdir -p "$(dirname "$QS_CONFIG_DIR")"
cp -r "$REPO_DIR/quickshell" "$QS_CONFIG_DIR"
info "Скопійовано в $QS_CONFIG_DIR"

if [ ! -f "$QS_CONFIG_DIR/scripts/.env" ] && [ -f "$QS_CONFIG_DIR/scripts/.env.example" ]; then
  cp "$QS_CONFIG_DIR/scripts/.env.example" "$QS_CONFIG_DIR/scripts/.env"
  warn "Створено scripts/.env з .env.example — заповни своїми HoYoLAB-даними, якщо потрібен Genshin-віджет"
  warn "(або просто вимкни enableGenshinWidget в $QS_CONFIG_DIR/Config.js)"
fi

# qs-bt-agent — BlueZ pairing agent, потрібен для показу PIN/confirm запитів
# при спарюванні. Без нього BtManager в шелі бачить пристрої, але не може
# їх запарувати. Ставимо як systemd user-сервіс (агент реєструється на
# системній D-Bus, root не потрібен).
chmod +x "$QS_CONFIG_DIR/qs-bt-agent"
mkdir -p "$HOME/.config/systemd/user"
cp "$QS_CONFIG_DIR/qs-bt-agent.service" "$HOME/.config/systemd/user/qs-bt-agent.service"
systemctl --user daemon-reload
systemctl --user enable --now qs-bt-agent.service
info "qs-bt-agent встановлено як systemd user-сервіс (systemctl --user status qs-bt-agent)"

# --- Крок 3 (опційно): решта дотфайлів — hypr/kitty/fish/yazi/starship ---
echo
read -rp "Скопіювати також hypr/kitty/fish/yazi/starship конфіги? Це ІНВАЗИВНО і зробить бекап існуючих. [y/N] " with_dotfiles
if [[ "$with_dotfiles" =~ ^[Yy]$ ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  for dir in hypr kitty fish yazi starship; do
    target="$HOME/.config/$dir"
    src="$REPO_DIR/$dir"
    [ -d "$src" ] || continue
    if [ -e "$target" ]; then
      backup="$target.bak-$ts"
      mv "$target" "$backup"
      warn "Існуючий $target збережено як $backup"
    fi
    cp -r "$src" "$target"
    info "Встановлено ~/.config/$dir"
  done
else
  info "Пропускаю hypr/kitty/fish/yazi/starship — встановлено тільки quickshell-шел."
fi

# --- Фінал ---
echo
info "Готово. Запусти шел командою:"
echo "    quickshell -c $SHELL_NAME"
echo
info "Щоб шел стартував разом з Hyprland, додай у hyprland.conf:"
echo "    exec-once = quickshell -c $SHELL_NAME"
echo
info "Щоб вимкнути окремі віджети (Genshin, Bluetooth тощо) без правки QML —"
info "редагуй $QS_CONFIG_DIR/Config.js"

# --- Крок 4 (опційно): автозапуск Hyprland при вході ---
# На чистому Arch немає greeter/display manager за замовчуванням — після
# встановлення система падає в голий TTY-логін, і Hyprland сам не стартує.
echo
info "На чистому Arch нема display manager — після входу система лишається в TTY."
read -rp "Налаштувати автозапуск Hyprland при вході? [y/N] " setup_autostart
if [[ "$setup_autostart" =~ ^[Yy]$ ]]; then
  aur_helper=""
  for h in yay paru; do
    command -v "$h" &>/dev/null && aur_helper="$h" && break
  done

  use_greeter="n"
  if [ -n "$aur_helper" ]; then
    read -rp "Знайдено '$aur_helper'. Встановити sysc-greet-hyprland (TUI-greeter, AUR)? [y/N] " use_greeter
    if [[ "$use_greeter" =~ ^[Yy]$ ]]; then
      "$aur_helper" -S sysc-greet-hyprland
      sudo systemctl enable greetd.service
      warn "Пакет поставлено. Онови /etc/greetd/config.toml вручну під свій запуск"
      warn "(initial_session command = \"Hyprland\", user = \"$USER\") — це системний"
      warn "конфіг, install.sh навмисно не редагує /etc за тебе. Деталі:"
      warn "https://nomadcxx.github.io/sysc-greet/compositors/hyprland/"
    fi
  else
    warn "AUR-хелпер (yay/paru) не знайдено — пропускаю встановлення sysc-greet-hyprland."
    warn "Постав його сам, якщо хочеш TUI-greeter: yay -S sysc-greet-hyprland"
  fi

  if [[ ! "$use_greeter" =~ ^[Yy]$ ]]; then
    info "Без greeter'а: додаю автозапуск Hyprland на tty1 через fish (без зайвих пакетів)."
    fish_config="$HOME/.config/fish/config.fish"
    if [ -f "$fish_config" ] && ! grep -q "exec Hyprland" "$fish_config"; then
      cat >> "$fish_config" << 'FISHEOF'

# Автостарт Hyprland при вході на tty1, якщо немає display manager
# і Wayland-сесія ще не запущена.
if status is-login
    and status is-interactive
    and test -z "$WAYLAND_DISPLAY"
    and test "$XDG_VTNR" = 1
    exec Hyprland
end
FISHEOF
      info "Додано в $fish_config"
    else
      info "Автозапуск вже налаштований або $fish_config не знайдено — пропускаю."
    fi
  fi
fi
