#!/usr/bin/env bash
set -euo pipefail

# ─── Root check ─────────────────────────────────────────────────
if (( EUID != 0 )); then
  echo "This script must be run as root. Use sudo!" >&2
  exit 1
fi

# ─── Identify user & paths ─────────────────────────────
normal_user=$(logname)
user_home=$(eval echo "~$normal_user")
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ─── Full system update & base tools ─────────────────────────
pacman -Syu --needed --noconfirm base-devel sudo git fish bash-completion

official_packages=(
  # Essentials
  otf-font-awesome
  adobe-source-sans-fonts
  ttf-sourcecodepro-nerd
  ttf-jetbrains-mono
  ttf-jetbrains-mono-nerd
  htop
  tldr
  mpv
  bat
  lsd
  curlie
  ly
  zoxide
  ripgrep
  git wget

  # fzf stack
  fzf
  fd

  # Wayland (Niri)
  wayland xorg-xwayland xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gnome xdg-desktop-portal-gtk
  networkmanager bluez-utils   # no GUI applets

  # Niri specific
  foot polkit-gnome wlr-randr grim slurp wl-clipboard swappy

  # Audio/Video
  pipewire wireplumber

  # X11 (dwm)
  xorg-server xorg-xinit xterm xorg-xset xwallpaper picom feh acpi xclip udisks2 thunar

  # System
  sudo fish bash-completion ufw

  # ── Noctalia runtime deps ──
  qt6-5compat
  cava
  gpu-screen-recorder
  swww
)
pacman -S --needed --noconfirm "${official_packages[@]}"

# ─── Enable & start essential services ────────────────────
systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now ufw
systemctl enable --now ly

# ─── Configure UFW ───────────────────────────
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# ─── AUR helper & packages ─────────────────────────
paru_packages=(
  evil-helix-bin	
  swayosd-git
  xwayland-satellite
  bibata-cursor-theme
  catppuccin-gtk-theme-mocha
  thorium-browser-avx2-bin
  niri
  dwm
  dmenu
  hyprlock
  wallust	
  ttf-material-symbols-variable-git	
  quickshell-git   # ← Noctalia shell
)
if command -v paru &> /dev/null; then
  sudo -u "$normal_user" paru -Syu --needed --noconfirm "${paru_packages[@]}"
else
  echo "⚠️ paru not found; skipping AUR packages (niri, dwm, quickshell)." >&2
fi

# ─── Rust & pfetch (optional) ───────────────────────
if ! command -v rustup &> /dev/null; then
  sudo -u "$normal_user" curl -sSf https://sh.rustup.rs \
    | sudo -u "$normal_user" sh -s -- -y
  sudo -u "$normal_user" "$user_home/.cargo/bin/rustup" default stable
fi
export PATH="$user_home/.cargo/bin:$PATH"
if ! command -v pfetch &> /dev/null; then
  sudo -u "$normal_user" cargo install pfetch
fi

# ─── Icon theme installer ─────────────────────────
if ! pacman -Q papirus-icon-theme &> /dev/null; then
  sudo -u "$normal_user" wget -qO- https://git.io/papirus-icon-theme-install | sh
fi

# ─── Sync local configs into ~/.config ─────────────────────
if [[ -d "$script_dir/config" ]]; then
  echo "Syncing $script_dir/config → $user_home/.config/"
  rsync -a --delete --chown="$normal_user":"$normal_user" \
    "$script_dir/config/" "$user_home/.config/"
else
  echo "No config/ folder found next to script; skipping."
fi

# ─── Clone & install Noctalia dotfiles ─────────────────────
sudo -u "$normal_user" git clone --depth 1 https://github.com/Ly-sec/Noctalia.git /tmp/noctalia
sudo -u "$normal_user" mkdir -p "$user_home/.config/quickshell"
sudo -u "$normal_user" rsync -a --delete --chown="$normal_user":"$normal_user" \
    /tmp/noctalia/ "$user_home/.config/quickshell/"



# ─── Setup Niri start script ─────────────────────────
cat > /usr/local/bin/start-niri << 'EOF'
#!/bin/sh
export TERMINAL=foot
exec niri-session
EOF
chmod +x /usr/local/bin/start-niri

# ─── Register Niri in Wayland sessions ──────────────
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/niri.desktop <<EOF
[Desktop Entry]
Name=Niri
Comment=Wayland session using Niri
Exec=/usr/local/bin/start-niri
Type=Application
DesktopNames=Niri
EOF

# ─── Setup DWM (Standard) ────────────────────────
cat > /usr/local/bin/start-dwm << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=dwm
export XDG_CURRENT_DESKTOP=dwm
exec dwm
EOF
chmod +x /usr/local/bin/start-dwm

# ─── Register DWM in X11 Sessions ──────────────
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/dwm.desktop <<EOF
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager
Exec=/usr/local/bin/start-dwm
Type=Application
EOF

# ─── Final message ──────────────────────────────
cat << EOF

✅ Minimal Arch + Noctalia setup complete!

• fish is now your default shell
• fzf, fd, bat, zoxide, fzf.fish ready to use
• ly is enabled
• quickshell-git + Noctalia dot-files installed

EOF

exit 0
