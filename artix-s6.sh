#!/usr/bin/env bash
set -euo pipefail
# Artix automated installer (runit, UEFI, GRUB, Arch repos + paru)
# WARNING: THIS WILL WIPE THE TARGET DISK (see DISK variable)

# --------- USER CONFIG (edit before running) -------------
DISK="/dev/sda"              # TARGET DISK (will be wiped)
EFI_SIZE_MIB=512             # EFI size in MiB
SWAP_SIZE_GIB=2              # swap size in GiB (set 0 to create no swap partition)
HOSTNAME="artixpc"
USERNAME="onishell"
PASSWORD="changeme"          # root and user password (plaintext here for automation). Consider changing interactively.
TIMEZONE="America/Santo_Domingo"
LOCALE="en_US.UTF-8"
LANG="en_US.UTF-8"
# --------------------------------------------------------

# derived
EFI_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"

echoblue(){ printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }
echored(){ printf "\n\033[1;31m!! %s\033[0m\n" "$1"; }

if [ "$(id -u)" -ne 0 ]; then
  echored "Run this script as root (from Artix live CD). Exiting."
  exit 1
fi

read -r -p "WARNING: This will wipe ${DISK}. Type YES to continue: " CONF
if [ "$CONF" != "YES" ]; then
  echored "Aborted by user."
  exit 1
fi

echoblue "1) Wiping disk and creating partitions on ${DISK}"
parted --script "${DISK}" \
  mklabel gpt \
  mkpart ESP fat32 1MiB "${EFI_SIZE_MIB}MiB" \
  set 1 boot on \
  name 1 efi

# Create swap if requested, then root
if [ "${SWAP_SIZE_GIB}" -gt 0 ]; then
  parted --script "${DISK}" \
    mkpart primary linux-swap "${EFI_SIZE_MIB}MiB" "$((EFI_SIZE_MIB + SWAP_SIZE_GIB * 1024))MiB" \
    name 2 swap
  parted --script "${DISK}" \
    mkpart primary ext4 "$((EFI_SIZE_MIB + SWAP_SIZE_GIB * 1024))MiB" 100% \
    name 3 root
else
  parted --script "${DISK}" \
    mkpart primary ext4 "${EFI_SIZE_MIB}MiB" 100% \
    name 2 root
  ROOT_PART="${DISK}2"
  SWAP_PART=""
fi

sleep 1

echoblue "2) Formatting partitions"
# EFI
mkfs.fat -F32 "${EFI_PART}"
# root
mkfs.ext4 -F "${ROOT_PART}"
# swap
if [ -n "${SWAP_PART}" ]; then
  mkswap "${SWAP_PART}"
  swapon "${SWAP_PART}"
fi

echoblue "3) Mounting partitions"
mount "${ROOT_PART}" /mnt
mkdir -p /mnt/boot
mount "${EFI_PART}" /mnt/boot

echoblue "4) Installing base system (basestrap)"
# packages: base, base-devel, runit, kernel, firmware, grub, efibootmgr, dosfstools, networkmanager (and runit helper), dbus runit helper, sudo
basestrap /mnt base base-devel runit linux linux-firmware grub efibootmgr dosfstools sudo networkmanager networkmanager-runit dbus-runit openssh vim

echoblue "5) Generate fstab"
fstabgen -U /mnt >> /mnt/etc/fstab

echoblue "6) Prepare Arch mirrorlist for /etc/pacman.d/mirrorlist-arch (Arch repos)"
# fetch Arch mirrorlist into new system
if command -v wget >/dev/null 2>&1; then
  wget -q "https://archlinux.org/mirrorlist/all/" -O /mnt/etc/pacman.d/mirrorlist-arch || true
else
  echored "wget not found in live environment; skipping mirrorlist download. You can add /etc/pacman.d/mirrorlist-arch manually later."
fi

echoblue "7) Add Arch repo blocks to new system pacman.conf (will append at end)"
cat >> /mnt/etc/pacman.conf <<'EOF'

# === Arch repositories (added by install script) ===
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

echoblue "8) chrooting into new system to finish configuration (this may take a while)"
CHROOT_CMD=""

if command -v artix-chroot >/dev/null 2>&1; then
  CHROOT_CMD="artix-chroot /mnt /bin/bash -e -c"
else
  CHROOT_CMD="arch-chroot /mnt /bin/bash -e -c"
fi

${CHROOT_CMD} "set -euo pipefail
# basic locale/time/hostname
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
echo '${LOCALE} UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=${LANG}' > /etc/locale.conf
echo '${HOSTNAME}' > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# root password
echo root:${PASSWORD} | chpasswd

# create user
useradd -m -G wheel -s /bin/bash '${USERNAME}'
echo '${USERNAME}:${PASSWORD}' | chpasswd

# allow wheel sudo
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers || true

# ensure dbus+networkmanager runit scripts are present (we installed networkmanager/networkmanager-runit dbus-runit)
# make sure runlevel default exists
mkdir -p /etc/runit/runsvdir/default

# enable dbus and NetworkManager for next boot (persistent runlevel)
ln -sf /etc/runit/sv/dbus /etc/runit/runsvdir/default/dbus || true
ln -sf /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager || true

# try to start them now for configuring network now (the /run dir will exist at runtime)
mkdir -p /run/runit/service
ln -sf /etc/runit/sv/dbus /run/runit/service/dbus || true
ln -sf /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager || true

# update package DB (with Arch repos available) and install some helpers
pacman -Syy --noconfirm
pacman -S --noconfirm --needed git base-devel

# Install paru from AUR (build in /tmp as regular user)
su - '${USERNAME}' -c 'cd /tmp && git clone https://aur.archlinux.org/paru.git || true && cd paru && makepkg -si --noconfirm || true'

# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Artix --recheck || true
grub-mkconfig -o /boot/grub/grub.cfg || true

# enable ssh if you want
ln -sf /etc/runit/sv/sshd /etc/runit/runsvdir/default/sshd || true

exit
"

echoblue "9) Cleanup, unmount and finish"
# turn off swap if we created one
if [ -n \"${SWAP_PART}\" ]; then
  swapoff "${SWAP_PART}" || true
fi

umount -R /mnt || true

echoblue "Installation finished. Reboot into your new Artix system:"
echo "  1) remove the live media"
echo "  2) reboot"
echo
echo "Notes:"
echo " - Edit /etc/pacman.d/mirrorlist-arch inside the new system if you want different Arch mirrors."
echo " - If you prefer a swap file instead of a swap partition, skip swap partition creation and create file later."
echo
