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
  ttf-jetbrains-mono-nerd
  matugen
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

for pkg in "${OPTIONAL_AUR_DEPS[@]}"; do
  if ! command -v "$pkg" &>/dev/null; then
    warn "'$pkg' не знайдено (опційно, тільки для динамічної теми з шпалер, доступний в AUR)."
    warn "Постав вручну своїм AUR-хелпером, якщо хочеш: <aur-helper> -S $pkg"
  fi
done

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
