#!/bin/bash

# Ultimate Artix Meta-Distribution - Complete CoolRune Adaptation
# Features: AMD GPU optimization, s6 init, River WM, all CoolRune tools
# Version: 2.0
# Hardware: AMD Ryzen 9 7940HS + Radeon RX 6800 XT

su -c '
### PACMAN RETRY FUNCTION (ENHANCED) ###
retry_pacman() {
    local max_attempts=5
    local attempt_num=1
    local command=("$@")
    local pkg_list=()
    local ignore_flag=""
    
    # Extract ignore flag and packages
    for arg in "${command[@]}"; do
        if [[ "$arg" == --ignore=* ]]; then
            ignore_flag="$arg"
        elif [[ "$arg" != "-S" && "$arg" != "--noconfirm" && "$arg" != "--needed" ]]; then
            pkg_list+=("$arg")
        fi
    done
    
    until pacman "${command[@]}"; do
        if (( attempt_num == max_attempts )); then
            echo "Attempt $attempt_num failed! Trying to continue with available packages..."
            
            # Check package availability
            local available_pkgs=()
            local failed_pkgs=()
            
            for pkg in "${pkg_list[@]}"; do
                if pacman -Sp "$pkg" &>/dev/null; then
                    available_pkgs+=("$pkg")
                else
                    failed_pkgs+=("$pkg")
                fi
            done
            
            if [ ${#failed_pkgs[@]} -gt 0 ]; then
                echo "Skipping unavailable packages: ${failed_pkgs[*]}"
            fi
            
            if [ ${#available_pkgs[@]} -gt 0 ]; then
                local new_cmd=(pacman -S --noconfirm --needed --overwrite='*')
                [ -n "$ignore_flag" ] && new_cmd+=("$ignore_flag")
                new_cmd+=("${available_pkgs[@]}")
                echo "Executing modified command: ${new_cmd[*]}"
                "${new_cmd[@]}" && return 0
            else
                echo "No available packages found, continuing..."
                return 0
            fi
        else
            echo "Attempt $attempt_num failed! Retrying in 5 seconds..."
            sleep 5
            ((attempt_num++))
        fi
    done
}

### REPOSITORY SETUP ###
echo "Configuring repositories and keys..."

# Import keys
pacman-key --init
pacman-key --populate archlinux artix
pacman-key --recv-keys 0FE58E8D1B980E51 F3B607488DB35A47 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 0FE58E8D1B980E51
pacman-key --lsign-key F3B607488DB35A47
pacman-key --lsign-key 3056513887B78AEB

# Add repositories
cat >> /etc/pacman.conf <<EOF
[cachyos]
Server = https://mirror.cachyos.org/repo/\$arch/\$repo

[alhp]
Server = https://mirror.gnomus.de/alhp/\$repo/os/\$arch
Server = https://mirror.maakpal.nl/alhp/\$repo/os/\$arch

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

# Install chaotic keyring
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

### SYSTEM OPTIMIZATION ###
echo "Optimizing system configuration..."

# Mirror optimization
pacman -Sy --noconfirm --needed reflector
reflector --latest 15 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

### HARDWARE SELECTION ###
echo -e "\e[1mSelect your hardware configuration\e[0m"
echo "1. AMD Desktop"
echo "2. AMD Laptop"
read -p "Enter your choice (1-2): " hw_choice

### BASE SYSTEM INSTALLATION ###
echo "Installing core system packages..."
retry_pacman -S --needed --noconfirm base-devel git cmake meson ninja rustup \
    linux-cachyos linux-cachyos-headers linux-cachyos-zfs \
    mesa-tkg-git lib32-mesa-tkg-git vulkan-radeon lib32-vulkan-radeon \
    amdvlk lib32-amdvlk libva-mesa-driver lib32-libva-mesa-driver \
    cpupower earlyoom zramen sof-firmware gamemode lib32-gamemode booster \
    apparmor chkrootkit clamav dnscrypt-proxy fail2ban lynis usbguard ufw \
    zfs-utils pipewire pipewire-alsa pipewire-pulse wireplumber \
    flatpak paru

### WINDOW MANAGER ESSENTIALS ###
echo "Installing River WM components..."
retry_pacman -S --needed --noconfirm river i3bar-river i3status-rust \
    xorg-server xorg-xinit xorg-xwayland foot wl-clipboard slurp grim \
    swaylock swayidle

### SECURITY SETUP ###
echo "Configuring security services..."

# AppArmor
mkdir -p /etc/s6/sv/apparmor
cat > /etc/s6/sv/apparmor/run <<EOF
#!/bin/sh
exec apparmor_parser -qKr /etc/apparmor.d
EOF
chmod +x /etc/s6/sv/apparmor/run
s6-service add default apparmor

# USBGuard
mkdir -p /etc/s6/sv/usbguard
cat > /etc/s6/sv/usbguard/run <<EOF
#!/bin/sh
exec usbguard-daemon -f -c /etc/usbguard/usbguard-daemon.conf
EOF
chmod +x /etc/s6/sv/usbguard/run
s6-service add default usbguard

# Fail2Ban
mkdir -p /etc/s6/sv/fail2ban
cat > /etc/s6/sv/fail2ban/run <<EOF
#!/bin/sh
exec fail2ban-server -xf start
EOF
chmod +x /etc/s6/sv/fail2ban/run
s6-service add default fail2ban

# DNSCrypt
s6-service add default dnscrypt-proxy

# UFW
s6-service add default ufw

### PERFORMANCE SERVICES ###
echo "Configuring performance services..."

# CPU Power
s6-service add default cpupower

# EarlyOOM
s6-service add default earlyoom

# ZRAM
s6-service add default zramen

# Laptop specific
if [ "$hw_choice" = "2" ]; then
    retry_pacman -S --needed --noconfirm tlp
    s6-service add default tlp
fi

# Reload s6
s6-db-reload

### AMD GPU OPTIMIZATION ###
echo "Applying AMD GPU optimizations..."

# Resizable BAR and performance tweaks
cat > /etc/default/grub <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Artix"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amdgpu.ppfeaturemask=0xffffffff amdgpu.gttsize=4096 pcie_aspm=off pcie_aspm.policy=performance amdgpu.vm_fragment_size=9 amdgpu.vm_update_mode=0"
GRUB_CMDLINE_LINUX=""
EOF

# Module configuration
cat > /etc/modprobe.d/amdgpu.conf <<EOF
options amdgpu ppfeaturemask=0xffffffff
options amdgpu cik_support=1
options amdgpu si_support=1
options amdgpu exp_hw_support=1
options amdgpu vm_size=256
options amdgpu vm_block_size=9
options amdgpu vm_fragment_size=9
options amdgpu deep_color=1
options amdgpu dc=1
options amdgpu aspm=0
EOF

# Update GRUB
grub-mkconfig -o /boot/grub/grub.cfg

### PERFORMANCE TUNING ###
echo "Applying performance tweaks..."

# CPU scheduler
echo "schedutil" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# ZRAM configuration
cat > /etc/default/zramen <<EOF
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

# EarlyOOM configuration
cat > /etc/default/earlyoom <<EOF
EARLYOOM_ARGS="-r 60 -m 5 -s 10 -M 2048000"
EOF

# GameMode setup
groupadd -f gamemode
usermod -aG gamemode "$USER"

# Low latency audio
cat > /etc/pipewire/pipewire.conf.d/99-lowlatency.conf <<EOF
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 32
    default.clock.min-quantum = 32
    default.clock.max-quantum = 32
}
EOF

### SECURITY HARDENING ###
echo "Applying security hardening..."

# Sysctl tweaks
cat > /etc/sysctl.d/99-security.conf <<EOF
# Kernel hardening
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.perf_event_paranoid=2
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2

# Network security
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_rfc1337=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

# Memory protection
vm.swappiness=10
vm.unprivileged_userfaultfd=0
EOF

# MAC address randomization
cat > /etc/NetworkManager/conf.d/00-macrandomize.conf <<EOF
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

### UTILITIES AND TOOLS ###
echo "Installing utilities and tools..."

# Data recovery tools
retry_pacman -S --needed --noconfirm testdisk photorec scalpel

# Media tools
retry_pacman -S --needed --noconfirm ffmpeg vlc obs-studio

# Productivity tools
retry_pacman -S --needed --noconfirm libreoffice-fresh hunspell hunspell-en_US

# Audio tools
retry_pacman -S --needed --noconfirm pulseaudio-alsa pavucontrol

# Network utilities
retry_pacman -S --needed --noconfirm nmap wireshark-qt whois

# System utilities
retry_pacman -S --needed --noconfirm htop btop lm_sensors inxi ncdu

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak install -y org.gnome.Shotwell org.kde.kdenlive

# Proton-GE
retry_pacman -S --needed --noconfirm protonup-qt
su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y"

### FINAL CONFIGURATION ###
echo "Finalizing configuration..."

# Create manual
mkdir -p /home/$USER/Documents/CoolRune_Manual
cat > /home/$USER/Documents/CoolRune_Manual/README.txt <<EOF
CoolRune Ultimate Meta-Distribution
===================================

Features:
- Artix Linux with s6 init
- River Window Manager
- AMD GPU Optimizations
- Enhanced Security Setup
- Performance Tuning
- Comprehensive Toolset

Hardware Notes:
- Resizable BAR enabled
- AMD Ryzen 9 7940HS + Radeon RX 6800 XT
- Zen 4 optimized kernel

Useful Commands:
- s6-rc-status: Check service status
- gamemoderun: Launch games with optimizations
- zramen status: Check ZRAM usage
- booster: Kernel management
EOF

# Set up booster
booster generate

# Clean up
pacman -Qtdq | pacman -Rns - --noconfirm 2>/dev/null || true
pacman -Sc --noconfirm

echo "Setting permissions..."
chmod 700 /etc/{sudoers,sudoers.d}
chmod 755 /etc/s6
chmod 644 /etc/modprobe.d/*

echo "CoolRune Ultimate setup complete! Rebooting in 10 seconds..."
sleep 10
reboot
'
