#!/bin/bash

# Artix Hyprland Minimal Setup
# Requires root execution: sudo ./scriptname

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Configuration
USERNAME=$(logname)  # Get logged-in user
USER_HOME=$(eval echo "~$USERNAME")

# Install essential packages
pacman -Sy --needed --noconfirm \
    hyprland \
    waybar \
    kitty \
    xdg-desktop-portal-hyprland \
    polkit-dinit \
    noto-fonts \
    noto-fonts-emoji \
    ttf-font-awesome \
    network-manager-applet \
    gvfs \
    gnome-keyring \
    playerctl \
    jq

# Enable dinit services
dinitctl enable NetworkManager
dinitctl enable polkit

# Create config directories
sudo -u "$USERNAME" mkdir -p "$USER_HOME"/.config/hypr
sudo -u "$USERNAME" mkdir -p "$USER_HOME"/.config/waybar
sudo -u "$USERNAME" mkdir -p "$USER_HOME"/.config/kitty

# Hyprland configuration
sudo -u "$USERNAME" cat > "$USER_HOME/.config/hypr/hyprland.conf" << 'EOF'
# Monitor setup (auto-detect recommended)
monitor=,preferred,auto,1

# Execute apps at launch
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = waybar
exec-once = nm-applet --indicator
exec-once = /usr/lib/polkit-kde-authentication-agent-1

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = yes
    }
}

# General appearance
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(88ccffee) rgba(00aaffee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Animations (minimal but polished)
animations {
    enabled = yes
    bezier = linear, 0.0, 0.0, 1.0, 1.0
    animation = windows, 1, 3, linear
    animation = border, 1, 5, linear
    animation = fade, 1, 5, linear
    animation = workspaces, 1, 3, linear
}

# Window rules
dwindle {
    pseudotile = yes
    preserve_split = yes
}

# Key bindings
$mainMod = SUPER
bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, V, togglefloating,
bind = $mainMod, J, togglesplit,
bind = $mainMod, F, fullscreen,
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Workspace rules
workspace = 1, default:true
workspace = 2
workspace = 3
workspace = 4
workspace = 5
EOF

# Waybar configuration
sudo -u "$USERNAME" cat > "$USER_HOME/.config/waybar/config" << 'EOF'
{
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["tray"],
    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },
    "clock": {
        "format": " {:L%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "tray": {
        "icon-size": 16,
        "spacing": 8
    }
}
EOF

# Waybar CSS
sudo -u "$USERNAME" cat > "$USER_HOME/.config/waybar/style.css" << 'EOF'
* {
    border: none;
    font-family: "Noto Sans", "Font Awesome 6 Free";
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.7);
    color: #cdd6f4;
    border-bottom: 1px solid rgba(100, 100, 100, 0.2);
}

#workspaces button {
    padding: 0 8px;
    color: #585b70;
    background: transparent;
    border-bottom: 2px solid transparent;
}

#workspaces button.active {
    color: #cdd6f4;
    border-bottom: 2px solid #89b4fa;
}

#workspaces button:hover {
    background: rgba(166, 173, 200, 0.15);
}

#clock {
    padding: 0 12px;
    color: #f5e0dc;
    background: rgba(180, 130, 173, 0.3);
    border-radius: 4px;
    margin: 4px 2px;
}

#tray {
    margin-right: 4px;
}
EOF

# Kitty configuration
sudo -u "$USERNAME" cat > "$USER_HOME/.config/kitty/kitty.conf" << 'EOF'
font_family      Noto Sans
font_size        11
scrollback_lines 2000
background_opacity 0.85
window_padding_width 8
EOF

# Set file permissions
chown -R "$USERNAME":"$USERNAME" "$USER_HOME/.config"

# Create autostart script
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.local/bin"
sudo -u "$USERNAME" cat > "$USER_HOME/.local/bin/hyprland-autostart" << 'EOF'
#!/bin/sh
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec dbus-launch Hyprland
EOF

chmod +x "$USER_HOME/.local/bin/hyprland-autostart"

# Update .bash_profile
echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec $USER_HOME/.local/bin/hyprland-autostart" | sudo -u "$USERNAME" tee -a "$USER_HOME/.bash_profile" > /dev/null

# Final instructions
echo "Installation complete!"
echo "Reboot and log in to start Hyprland automatically."
echo "Basic controls:"
echo "  Super + Enter: Launch terminal"
echo "  Super + Q: Close window"
echo "  Super + M: Exit session"
echo "  Super + [1-5]: Switch workspaces"
