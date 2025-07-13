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

# ─── Official repo packages ─────────────────────────
official_packages=(
  micro vim neovim tldr mpv bat wayland xorg-xwayland
  xdg-utils xdg-user-dirs xdg-desktop-portal-wlr
  networkmanager network-manager-applet bluez-utils blueman
  git wget river ly foot polkit-gnome waybar wlr-randr kanshi
  fuzzel swaybg swayidle mako
  otf-font-awesome adobe-source-sans-fonts ttf-sourcecodepro-nerd
  ttf-jetbrains-mono ttf-jetbrains-mono-nerd pavucontrol pamixer
  ufw grim slurp wl-clipboard swappy htop lsd file-roller
  gvfs imv mousepad curlie yazi ffmpeg p7zip jq poppler fd
  ripgrep fzf zoxide imagemagick
  xorg-server xorg-xinit xterm xorg-xset xwallpaper picom feh acpi rofi
  xclip
  udisks2
)
pacman -S --needed --noconfirm "${official_packages[@]}"

# ─── Enable & start essential services ────────────────────
systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now ufw

# ─── Configure UFW ───────────────────────────
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# ─── Polkit rule for udisks2 auto-mount permissions ───────────
mkdir -p /etc/polkit-1/localauthority/50-local.d/
cat > /etc/polkit-1/localauthority/50-local.d/50-udisks2.pkla <<EOF
[Allow udisks2 mounting for users]
Identity=unix-group:plugdev;unix-group:lpadmin;unix-user:*
Action=org.freedesktop.udisks2.filesystem-mount*;org.freedesktop.udisks2.drive-eject
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

# ─── UDisks2 config with automount enabled ─────────────
mkdir -p /etc/udisks2
cat > /etc/udisks2/udisks2.conf <<EOF
[defaults]
defaults=noexec,noatime,nodiratime
mount_options=noexec,noatime,nodiratime
automount=true
automount-interval=10
EOF

# ─── Create user mount directory ────────────────────────
sudo -u "$normal_user" mkdir -p "$user_home/Media"

# ─── Restart udisks2 and polkit services ───────────────
systemctl restart udisks2
systemctl restart polkit

# ─── AUR helper & packages ─────────────────────────
paru_packages=(
  resvg
  catppuccin-gtk-theme-mocha
  thorium-browser-avx2-bin
)
if command -v paru &> /dev/null; then
  sudo -u "$normal_user" paru -Syu --needed --noconfirm "${paru_packages[@]}"
else
  echo "⚠️ paru not found; skipping AUR packages." >&2
fi

# ─── Rust & pfetch (optional) ───────────────────────
if ! command -v rustup &> /dev/null; then
  sudo -u "$normal_user" curlie -sSf https://sh.rustup.rs \
    | sudo -u "$normal_user" sh -s -- -y
  sudo -u "$normal_user" "$user_home/.cargo/bin/rustup" default stable
fi
export PATH="$user_home/.cargo/bin:$PATH"
if ! command -v pfetch &> /dev/null; then
  sudo -u "$normal_user" cargo install pfetch
fi

# ─── Icon theme installer ─────────────────────────
if ! command -v papirus-icon-theme &> /dev/null; then
  sudo -u "$normal_user" wget -qO- https://git.io/papirus-icon-theme-install | sh
fi

# ─── Sync local configs into ~/.config ───────────────
if [[ -d "$script_dir/config" ]]; then
  echo "Syncing $script_dir/config → $user_home/.config/"
  rsync -a --delete --chown="$normal_user":"$normal_user" \
    "$script_dir/config/" "$user_home/.config/"
else
  echo "No config/ folder found next to script; skipping."
fi

# ─── Set up terminal-based xdg-open handler for directories ─────
xdg_open_script="$user_home/.local/bin/xdg-terminal-open"
xdg_open_desktop="$user_home/.local/share/applications/xdg-terminal-open.desktop"

sudo -u "$normal_user" mkdir -p "$(dirname "$xdg_open_script")" "$(dirname "$xdg_open_desktop")"

sudo -u "$normal_user" tee "$xdg_open_script" > /dev/null <<'EOF'
#!/bin/sh
TERMINAL="${TERMINAL:-foot}"
FM="${FILE_MANAGER:-yazi}"
TARGET="$1"
[ -f "$TARGET" ] && TARGET="$(dirname "$TARGET")"
exec "$TERMINAL" -e "$FM" "$TARGET"
EOF
chmod +x "$xdg_open_script"

sudo -u "$normal_user" tee "$xdg_open_desktop" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=Terminal File Manager
Exec=$xdg_open_script %u
MimeType=inode/directory;
NoDisplay=true
EOF

sudo -u "$normal_user" xdg-mime default xdg-terminal-open.desktop inode/directory

# ─── Setup River start script ─────────────────────────
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

# ─── Register River in Wayland sessions ──────────────
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/river.desktop <<EOF
[Desktop Entry]
Name=River
Comment=Wayland session using River
Exec=/usr/local/bin/start-river
Type=Application
DesktopNames=river
EOF

# ─── Install & setup ChadWM ────────────────────────
rm -rf "$user_home/.config/chadwm"
sudo -u "$normal_user" git clone https://github.com/siduck/chadwm --depth 1 "$user_home/.config/chadwm"
cd "$user_home/.config/chadwm"
sudo -u "$normal_user" mv eww "$user_home/.config"
cd chadwm
sudo -u "$normal_user" chmod +x ../scripts/*.sh
make clean install

# ─── Register ChadWM in Display Manager ──────────────
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/chadwm.desktop <<EOF
[Desktop Entry]
Name=chadwm
Comment=dwm made beautiful
Exec=$user_home/.config/chadwm/scripts/run.sh
Type=Application
EOF
chown -R "$normal_user:$normal_user" "$user_home/.config/chadwm"

# ─── Clipboard and wallpaper setup for ChadWM ────────────
sudo -u "$normal_user" bash -c "pgrep xclip || xclip -selection clipboard -o >/dev/null &"
sudo -u "$normal_user" xwallpaper --zoom "$user_home/.config/river/wallpapers/forest.png" &

# ─── Final message ──────────────────────────────
cat << EOF

✅ Arch setup complete!

• You can now log into either:
  ✔ River (Wayland)
  ✔ ChadWM (X11 dwm fork)

• Log out and back in (or restart shell):
    sudo -u $normal_user fish

• Update TLDR cache:
    tldr --update

• Adjust firewall rules:
    ufw allow <port>
    ufw status

EOF

exit 0

