#!/usr/bin/env bash
set -euo pipefail

# ──── Root Check ───────────────────────────────────
if (( EUID != 0 )); then
  echo "This script must be run as root. Use sudo!" >&2
  exit 1
fi

# ──── User & Path Setup ────────────────────────────
normal_user=$(logname)
user_home=$(eval echo "~$normal_user")
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ──── Package Arrays ───────────────────────────────
BASE_PACKAGES=(
  base-devel sudo git fish
  otf-font-awesome adobe-source-sans-fonts
  ttf-sourcecodepro-nerd ttf-jetbrains-mono ttf-jetbrains-mono-nerd
  htop mpv bat lsd curlie ly zoxide ripgrep wget xdg-utils
  networkmanager bluez-utils pipewire wireplumber
  xorg-server xorg-xinit xterm feh acpi xclip udisks2 thunar
  ufw polkit-gnome grim slurp wl-clipboard swappy wlr-randr
  pulsemixer mako playerctl kanshi swaync fd
)

DWM_PACKAGES=(dwm dmenu picom xwallpaper)

RIVER_PACKAGES=(
  river
  bluetui
)


AUR_COMMON=(
  yambar-git
  tofi
  evil-helix-bin
  catppuccin-gtk-theme-mocha
  thorium-browser-avx2-bin
)

# ──── Functions ────────────────────────────────────

install_aur_helper() {
  if ! command -v paru &> /dev/null; then
    echo "Installing paru AUR helper..."
    sudo -u "$normal_user" git clone https://aur.archlinux.org/paru-bin.git /tmp/paru
    cd /tmp/paru
    sudo -u "$normal_user" makepkg -si --noconfirm
    cd "$script_dir"
  fi
}

install_base_packages() {
  echo "Installing base packages..."
  pacman -Syu --needed --noconfirm "${BASE_PACKAGES[@]}" "${OFFICIAL_COMMON[@]}"

  echo "Installing DWM fallback..."
  pacman -S --needed --noconfirm "${DWM_PACKAGES[@]}"
}

install_river_packages() {
  echo "Installing River setup..."
  pacman -S --needed --noconfirm "${RIVER_PACKAGES[@]}"
  sudo -u "$normal_user" paru -S --needed --noconfirm "${AUR_COMMON[@]}"
}

setup_services() {
  systemctl enable --now NetworkManager
  systemctl enable --now bluetooth
  systemctl enable --now ufw
  systemctl enable --now ly

  ufw default deny incoming
  ufw default allow outgoing
  ufw --force enable
}

setup_rust() {
  if ! command -v rustup &> /dev/null; then
    sudo -u "$normal_user" curl -sSf https://sh.rustup.rs | sh -s -- -y
    sudo -u "$normal_user" "$user_home/.cargo/bin/rustup" default stable
  fi
  export PATH="$user_home/.cargo/bin:$PATH"

  if ! command -v pfetch &> /dev/null; then
    sudo -u "$normal_user" cargo install pfetch
  fi
}

setup_icons() {
  if ! pacman -Q papirus-icon-theme &> /dev/null; then
    sudo -u "$normal_user" wget -qO- https://git.io/papirus-icon-theme-install | sh
  fi
}

setup_mime_types() {
  echo "Setting up XDG MIME types for Thunar..."
  sudo -u "$normal_user" mkdir -p "$user_home/.config"

  cat > "$user_home/.config/mimeapps.list" <<EOF
[Default Applications]
inode/directory=thunar.desktop
x-scheme-handler/http=thorium-browser.desktop
x-scheme-handler/https=thorium-browser.desktop

[Added Associations]
inode/directory=thunar.desktop;
text/html=thorium-browser.desktop;
x-scheme-handler/http=thorium-browser.desktop;
x-scheme-handler/https=thorium-browser.desktop;
EOF

  chown "$normal_user":"$normal_user" "$user_home/.config/mimeapps.list"
}

sync_configs() {
  if [[ -d "$script_dir/config" ]]; then
    echo "Merging configs from $script_dir/config to $user_home/.config/"
    sudo -u "$normal_user" rsync -a \
      "$script_dir/config/" "$user_home/.config/"
    chown -R "$normal_user":"$normal_user" "$user_home/.config"
  else
    echo "No config directory found"
  fi
}

setup_dwm_session() {
  echo "Setting up DWM fallback session..."
  cat > /usr/local/bin/start-dwm << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=dwm
export XDG_CURRENT_DESKTOP=dwm
exec dwm
EOF
  chmod +x /usr/local/bin/start-dwm

  cat > /usr/share/xsessions/dwm.desktop <<EOF
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager
Exec=/usr/local/bin/start-dwm
Type=Application
EOF
}

setup_river_session() {
  echo "Setting up River session..."
  cat > /usr/local/bin/start-river << 'EOF'
#!/bin/sh
export TERMINAL=foot
export BROWSER=thorium
export XDG_CURRENT_DESKTOP=river
export GTK_USE_PORTAL=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

river &
swbar &
wait
EOF
  chmod +x /usr/local/bin/start-river

  mkdir -p /usr/share/wayland-sessions
  cat > /usr/share/wayland-sessions/river.desktop <<EOF
[Desktop Entry]
Name=River
Comment=Wayland session using River
Exec=/usr/local/bin/start-river
Type=Application
DesktopNames=River
EOF
}

setup_tui_network() {
  echo "Installing tui-network..."
  # Install UV to user's local bin
  sudo -u "$normal_user" curl -LsSf https://astral.sh/uv/install.sh | sh -s --

  # Ensure completion directory exists
  sudo -u "$normal_user" mkdir -p "$user_home/.config/fish/completions"
  
  # Generate completions using the correct uv binary
  sudo -u "$normal_user" "$user_home/.local/bin/uv" completions fish > "$user_home/.config/fish/completions/uv.fish"
  
  # Install tui-network
  sudo -u "$normal_user" git clone https://github.com/Zatfer17/tui-network /tmp/tui-network
  cd /tmp/tui-network
  sudo -u "$normal_user" "$user_home/.local/bin/uv" tool install .
  cd "$script_dir"
}

setup_fish_tools() {
  fisher install kidonng/zoxide.fish
  fisher install alin23/tldr
  fisher install PatrickF1/fzf.fish
}

# ──── Main Script ──────────────────────────────────

echo "Installing River with DWM fallback..."
setup="river"

# Base installation
install_base_packages
install_aur_helper
setup_services
setup_rust
setup_icons

# Install River & AUR tools
install_river_packages
setup_river_session

# Common setup
setup_dwm_session
sync_configs
setup_mime_types

#setup_tui_network
# setup_fish_tools
# Final message
cat << EOF

✅ Arch Linux + River setup complete!

Components installed:
- River window manager
- DWM fallback session
- tui-network TUI for Wi-Fi management
- Essential CLI tools
- Wayland utilities
- Fonts and themes
- Thunar as default file manager

Start options available in display manager:
- River
- DWM (fallback)

Config files merged from:
$script_dir/config

EOF
