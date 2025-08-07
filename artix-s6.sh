#!/bin/sh

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Set target disk and partitions (adjust as needed)
TARGET_DISK="/dev/sda"
BOOT_PART="${TARGET_DISK}1"
ROOT_PART="${TARGET_DISK}2"

# Partition the disk
echo "Partitioning the disk..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart primary 0% 512MiB
parted -s "$TARGET_DISK" set 1 boot on
part Target_DISK="${TARGET_DISK}2"

# Partition the disk
echo "Partitioning the disk..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart primary 0% 512MiB
parted -s "$TARGET_DISK" set 1 boot on
parted -s "$TARGET_DISK" mkpart primary 512MiB 100%

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 "$BOOT_PART"
mkfs.ext4 "$ROOT_PART"

# Mount partitions
echo "Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir /mnt/boot
mount "$BOOT_PART" /mnt/boot

# Install base system and essential packages
echo "Installing base system and packages..."
basestrap /mnt base base-devel dinit dinit-artix git wlroots wayland wayland-protocols libxkbcommon xorg-xwayland pipewire pipewire-pulse wireplumber bluez bluez-utils dunst foot ttf-dejavu swaybg grub efibootmgr

# Generate fstab
echo "Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

# Chroot into the new system for configuration
echo "Configuring the system..."
artix-chroot /mnt /bin/bash <<EOF

# Set hostname
echo "artix" > /etc/hostname

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set timezone (adjust as needed)
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

# Set root password
echo "root:root" | chpasswd

# Enable Arch mirrors for additional packages
pacman -S --noconfirm artix-archlinux-support
echo -e "\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n\n[multilib]\nInclude = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
pacman -Syu --noconfirm

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=artix
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -G wheel,audio,video,bluetooth -s /bin/bash user
echo "user:user" | chpasswd

# Set up sudo
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Clone and build DWL
su - user -c "mkdir -p /home/user/.local/src"
su - user -c "git clone https://codeberg.org/oceanicc/dwl /home/user/.local/src/dwl"
su - user -c "cd /home/user/.local/src/dwl && [ -f config.def.h ] && cp config.def.h config.h"
su - user -c "cd /home/user/.local/src/dwl && make && sudo make install"

# Clone and build minibar
su - user -c "git clone https://codeberg.org/oceanicc/minibar /home/user/.local/src/minibar"
su - user -c "cd /home/user/.local/src/minibar && make && sudo make install"

# Configure foot terminal
mkdir -p /home/user/.config/foot
cat << 'EOT' > /home/user/.config/foot/foot.ini
[main]
font=monospace:size=12
[colors]
background=002b36
foreground=839496
regular0=073642
regular1=dc322f
regular2=859900
regular3=b58900
regular4=268bd2
regular5=d33682
regular6=2aa198
regular7=eee8d5
EOT

# Configure Dunst notification daemon
mkdir -p /home/user/.config/dunst
cat << 'EOT' > /home/user/.config/dunst/dunstrc
[global]
    font = Monospace 10
    geometry = "300x5-30+20"
    transparency = 10
    frame_color = "#002b36"
    separator_color = frame
[urgency_low]
    background = "#002b36"
    foreground = "#839496"
[urgency_normal]
    background = "#073642"
    foreground = "#eee8d5"
[urgency_critical]
    background = "#dc322f"
    foreground = "#fdf6e3"
EOT

# Create DWL startup script
mkdir -p /home/user/.local/bin
cat << 'EOT' > /home/user/.local/bin/startdwl.sh
#!/bin/sh
swaybg -c '#002b36' &
pipewire &
pipewire-pulse &
wireplumber &
dunst &
dwl -b /usr/local/bin/minibar
EOT
chmod +x /home/user/.local/bin/startdwl.sh

# Enable services with Dinit
dinitctl enable bluetoothd

# Set ownership
chown -R user:user /home/user/.config /home/user/.local

# Exit chroot
exit
EOF

# Unmount partitions
echo "Unmounting partitions..."
umount -R /mnt

echo "Installation complete! Reboot to use your new Artix system."
