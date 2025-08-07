#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Get the username from the first argument
USER=$1

# Check if the user exists
if ! id "$USER" &>/dev/null; then
    echo "User $USER does not exist"
    exit 1
fi

# Install necessary packages (including Pipewire and Bluetooth)
pacman -S --needed hyprland waybar kitty sddm swaybg ttf-dejavu xwayland \
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
    bluez bluez-utils blueman

# Enable sddm and bluetooth services
systemctl enable sddm
systemctl enable bluetooth

# Create config directories
mkdir -p /home/$USER/.config/hypr
mkdir -p /home/$USER/.config/waybar

# Write Hyprland configuration
cat << EOF > /home/$USER/.config/hypr/hyprland.conf
# Hyprland configuration
monitor=,preferred,auto,1

input {
    kb_layout = us
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = 0x66ee1111
    col.inactive_border = 0x66333333
}

decoration {
    rounding = 5
    drop_shadow = yes
    shadow_range = 10
    shadow_render_power = 3
}

animations {
    enabled = yes
    animation = windows, 1, 3, default
    animation = fade, 1, 3, default
}

# Keybindings
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10

# Execute on startup
exec-once = swaybg -c #002b36
exec-once = waybar
exec-once = blueman-applet
EOF

# Write Waybar configuration (with pulseaudio and tray modules)
cat << EOF > /home/$USER/.config/waybar/config
{
    "layer": "top",
    "position": "top",
    "height": 24,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": [],
    "modules-right": ["pulseaudio", "clock", "tray"],
    "hyprland/workspaces": {
        "format": "{name}"
    },
    "clock": {
        "format": "{:%H:%M}"
    },
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-icons": {
            "default": ["", "", ""]
        }
    },
    "tray": {
        "spacing": 10
    }
}
EOF

# Set ownership of config files
chown -R $USER:$USER /home/$USER/.config/hypr
chown -R $USER:$USER /home/$USER/.config/waybar

# Enable Pipewire user services
runuser -u $USER -- systemctl --user enable pipewire pipewire-pulse wireplumber

# Completion message
echo "Setup complete. Audio and Bluetooth have been configured with Pipewire and Blueman."
echo "Please reboot the system to start using Hyprland with full audio and Bluetooth support."
echo "For more information on using Hyprland, visit https://wiki.hyprland.org"
