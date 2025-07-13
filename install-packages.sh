#!/usr/bin/env bash
set -euo pipefail

# ─── Root check ──────────────────────────────────────────────────
if (( EUID != 0 )); then
  echo "This script must be run as root. Use sudo!" >&2
  exit 1
fi

# ─── Identify user & paths ───────────────────────────────────────
normal_user=$(logname)
user_home=$(eval echo "~$normal_user")
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ─── Full system update & base tools ─────────────────────────────
pacman -Syu --needed --noconfirm base-devel sudo git fish bash-completion

# ─── Official repo packages ──────────────────────────────────────
official_packages=(
  micro vim neovim tldr mpv zeal bat wayland xorg-xwayland
  xdg-utils xdg-user-dirs xdg-desktop-portal-wlr
  networkmanager network-manager-applet bluez-utils blueman
  git wget river ly foot polkit-gnome waybar wlr-randr kanshi
  fuzzel swaybg swayidle swaync udiskie
  otf-font-awesome adobe-source-sans-fonts ttf-sourcecodepro-nerd
  ttf-jetbrains-mono ttf-jetbrains-mono-nerd pavucontrol pamixer
  ufw grim slurp wl-clipboard swappy htop lsd firefox file-roller
  gvfs imv mousepad curlie yazi ffmpeg p7zip jq poppler fd
  ripgrep fzf zoxide imagemagick
  # DWM session fallback
  xorg-server xorg-xinit xterm xset xwallpaper
  dwm dmenu st slstatus
)
pacman -S --needed --noconfirm "${official_packages[@]}"

# ─── Enable & start essential services ───────────────────────────
systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now ufw

# ─── Configure UFW ───────────────────────────────────────────────
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# ─── AUR helper & packages ───────────────────────────────────────
paru_packages=(
  resvg
  catppuccin-gtk-theme-mocha
)
if command -v paru &> /dev/null; then
  sudo -u "$normal_user" paru -Syu --needed --noconfirm "${paru_packages[@]}"
else
  echo "⚠️ paru not found; skipping AUR packages." >&2
fi

# ─── Rust & pfetch (optional) ────────────────────────────────────
if ! command -v rustup &> /dev/null; then
  sudo -u "$normal_user" curlie -sSf https://sh.rustup.rs \
    | sudo -u "$normal_user" sh -s -- -y
  sudo -u "$normal_user" "$user_home/.cargo/bin/rustup" default stable
fi
export PATH="$user_home/.cargo/bin:$PATH"
if ! command -v pfetch &> /dev/null; then
  sudo -u "$normal_user" cargo install pfetch
fi

# ─── Icon theme installer ─────────────────────────────────────────
if ! command -v papirus-icon-theme &> /dev/null; then
  sudo -u "$normal_user" wget -qO- https://git.io/papirus-icon-theme-install | sh
fi

# ─── Sync local configs into ~/.config ───────────────────────────
if [[ -d "$script_dir/config" ]]; then
  echo "Syncing $script_dir/config → $user_home/.config/"
  rsync -a --delete --chown="$normal_user":"$normal_user" \
    "$script_dir/config/" "$user_home/.config/"
else
  echo "No config/ folder found next to script; skipping."
fi

# ─── Setup River start script ────────────────────────────────────
cat > /usr/local/bin/start-river << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=river
export XDG_CURRENT_DESKTOP=river

export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1

exec river
EOF
chmod +x /usr/local/bin/start-river

# ─── Register River in Wayland sessions ──────────────────────────
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/river.desktop <<EOF
[Desktop Entry]
Name=River
Comment=Wayland session using River
Exec=/usr/local/bin/start-river
Type=Application
DesktopNames=river
EOF

# ─── Setup DWM .xinitrc ──────────────────────────────────────────
cat > "$user_home/.xinitrc" << 'EOF'
#!/bin/sh
xsetroot -cursor_name left_ptr
xset r rate 300 50 &
xwallpaper --zoom ~/.config/river/wallpapers/river-wp2.jpg &
slstatus &
exec dwm
EOF
chown "$normal_user:$normal_user" "$user_home/.xinitrc"
chmod +x "$user_home/.xinitrc"

# ─── Register DWM in Ly sessions ────────────────────────────────
mkdir -p /etc/X11/Sessions
cat > /etc/X11/Sessions/dwm.desktop <<EOF
[Desktop Entry]
Name=DWM
Comment=Minimal X11 session with dwm
Exec=/bin/bash -lc startx
Type=Application
EOF

# ─── Final message ───────────────────────────────────────────────
cat << EOF

✅ Arch setup complete!

• You can now log into either:
  ✔ River (Wayland)
  ✔ DWM (X11 fallback)

• Log out and back in (or restart shell):
    sudo -u $normal_user fish

• Update TLDR cache:
    tldr --update

• Adjust firewall rules:
    ufw allow <port>
    ufw status
EOF

exit 0

