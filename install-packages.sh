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
    micro vim nvim tldr mpv tldr bat wayland xorg-xwayland
    xdg-utils xdg-user-dirs xdg-desktop-portal-wlr
    networkmanager network-manager-applet bluez-utils blueman
    git wget river ly foot polkit-gnome waybar wlr-randr kanshi
    fuzzel swaybg swayidle swaync udiskie
    otf-font-awesome adobe-source-sans-fonts ttf-sourcecodepro-nerd
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd pavucontrol pamixer
    ufw grim slurp wl-clipboard swappy htop lsd firefox file-roller
    gvfs imv mousepad curlie yazi ffmpeg p7zip jq poppler fd
    ripgrep fzf zoxide imagemagick
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
    thorium-browser-avx2-bin
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

# ─── Final message ───────────────────────────────────────────────
cat << EOF

✅ Arch setup complete!

• Log out and back in (or restart shell):
    sudo -u $normal_user fish

• Update tldr cache when needed:
    tldr --update

• Adjust firewall rules:
    ufw allow <service|port>
    ufw status

EOF

exit 0

