#!/usr/bin/env bash
set -euo pipefail
# Artix automated installer (runit, UEFI, GRUB, Arch repos + paru)
# Aggressively unmounts and wipes existing partitions on the target DISK.
# WARNING: This will irreversibly destroy data on DISK.

# --------- USER CONFIG (edit before running) -------------
DISK="/dev/nvme0n1"              # TARGET DISK (will be wiped) - change this!
EFI_SIZE_MIB=512             # EFI size in MiB
SWAP_SIZE_GIB=4              # swap size in GiB (set 0 to create no swap partition)
HOSTNAME="artixpc"
USERNAME="dev"
PASSWORD="toor"          # root and user password (plaintext here for automation). Consider changing interactively.
TIMEZONE="America/Santo_Domingo"
LOCALE="en_US.UTF-8"
LANG="en_US.UTF-8"
# --------------------------------------------------------

echoblue(){ printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }
echored(){ printf "\n\033[1;31m!! %s\033[0m\n" "$1"; }

if [ "$(id -u)" -ne 0 ]; then
  echored "Run this script as root (from Artix live CD). Exiting."
  exit 1
fi

read -r -p "DANGER: This will destroy all data on ${DISK}. Type YES to continue: " CONF
if [ "$CONF" != "YES" ]; then
  echored "Aborted by user."
  exit 1
fi

# Sanity check - disk exists
if [ ! -b "${DISK}" ]; then
  echored "Device ${DISK} not found or not a block device."
  exit 1
fi

# Helper: list partition device names for given disk
get_partitions() {
  # Print /dev/NAME for each partition (excludes the whole-disk entry)
  lsblk -ln -o NAME,TYPE "${DISK}" | awk '$2=="part" {print "/dev/" $1}'
}

# 0) Swapoff any swap on this disk
echoblue "Stopping swap devices on ${DISK} (if any)"
while read -r swapdev; do
  if [[ "$swapdev" == "${DISK}"* || "$swapdev" == /dev/* && "$(readlink -f "$swapdev")" == "${DISK}"* ]]; then
    echoblue "swapoff $swapdev"
    swapoff "$swapdev" || true
  fi
done < <(awk 'NR>1 {print $1}' /proc/swaps || true)

# 1) If LUKS volumes open on disk, try to close them (best-effort)
echoblue "Closing LUKS/cryptsetup mappings related to ${DISK} (if any)"
if command -v cryptsetup >/dev/null 2>&1; then
  for m in /dev/mapper/*; do
    # check backing device of mapping (best-effort using dmsetup info)
    if dmsetup table "$(basename "$m")" >/dev/null 2>&1; then
      if dmsetup table "$(basename "$m")" | grep -q "${DISK}" || dmsetup info "$(basename "$m")" 2>/dev/null | grep -q "${DISK}"; then
        echoblue "cryptsetup luksClose $(basename "$m")"
        cryptsetup luksClose "$(basename "$m")" || true
      fi
    fi
  done
fi

# 2) Deactivate and remove LVM volumes that use this disk (best-effort)
echoblue "Scanning for LVM Physical Volumes on ${DISK}"
if command -v pvs >/dev/null 2>&1; then
  # list PVs and try to remove associated LVs/VGs
  while read -r pv; do
    if [[ "$pv" == "${DISK}"* ]]; then
      echoblue "pvdisplay $pv ; trying to deactivate/remove VG/LV (best-effort)"
      # find VG
      vg=$(pvs --noheadings -o vg_name "$pv" 2>/dev/null | awk '{print $1}' || true)
      if [ -n "$vg" ]; then
        echoblue "vgchange -an $vg"
        vgchange -an "$vg" || true
        echoblue "vgremove -f $vg"
        vgremove -f "$vg" || true
      fi
      echoblue "pvremove -ff $pv"
      pvremove -ff "$pv" || true
    fi
  done < <(pvs --noheadings -o pv_name 2>/dev/null | awk '{print $1}' || true)
fi

# 3) Forcibly unmount partitions and kill processes using them
echoblue "Forcibly unmounting partitions on ${DISK} and killing processes using them"
for part in $(get_partitions); do
  # kill processes using the block device
  if command -v fuser >/dev/null 2>&1; then
    echoblue "fuser -km ${part} || true"
    fuser -km "${part}" 2>/dev/null || true
    sleep 1
  fi
  # lazy unmount (works even if busy) and fallback to force
  echoblue "umount -l ${part} || true"
  umount -l "${part}" 2>/dev/null || true
done

# Extra: unmount targets that are mounted from this disk (findmnt)
echoblue "Unmounting mountpoints that reference ${DISK} via findmnt"
if command -v findmnt >/dev/null 2>&1; then
  while read -r target src; do
    # src may be /dev/sda1
    if [[ "$src" == "${DISK}"* ]]; then
      echoblue "umount -l $target || true"
      umount -l "$target" 2>/dev/null || true
    fi
  done < <(findmnt -rn -o TARGET,SOURCE || true)
fi

# 4) Wipe filesystem signatures on partitions (wipefs)
echoblue "Wiping filesystem signatures (wipefs -a) on partitions of ${DISK}"
for part in $(get_partitions); do
  echoblue "wipefs -a $part || true"
  wipefs -a "$part" || true
done

# 5) Zap partition table (sgdisk) and zero first MiB
echoblue "Zapping GPT/MBR data on ${DISK} (sgdisk --zap-all + dd zero first MiB)"
if command -v sgdisk >/dev/null 2>&1; then
  sgdisk --zap-all "${DISK}" || true
fi

# Zero the first 2 MiB (clear protective MBR/GPT headers)
dd if=/dev/zero of="${DISK}" bs=1M count=2 conv=fsync status=progress || true

# Inform kernel to re-read partition table
partprobe "${DISK}" || true
sleep 1
udevadm settle || true

# Recompute derived partition variables (because partition numbering may change)
# We'll create partitions now.
if [ "${SWAP_SIZE_GIB}" -gt 0 ]; then
  EFI_PART="${DISK}1"
  SWAP_PART="${DISK}2"
  ROOT_PART="${DISK}3"
else
  EFI_PART="${DISK}1"
  SWAP_PART=""
  ROOT_PART="${DISK}2"
fi

echoblue "Partition table wiped. Creating new partition table and partitions now."

# 6) Create GPT and partitions
parted --script "${DISK}" \
  mklabel gpt \
  mkpart ESP fat32 1MiB "${EFI_SIZE_MIB}MiB" \
  set 1 boot on \
  name 1 efi

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
fi

sleep 1
partprobe "${DISK}" || true
udevadm settle || true

echoblue "Formatting partitions"
mkfs.fat -F32 "${EFI_PART}"
mkfs.ext4 -F "${ROOT_PART}"
if [ -n "${SWAP_PART}" ]; then
  mkswap "${SWAP_PART}"
  swapon "${SWAP_PART}"
fi

echoblue "Mounting partitions"
mount "${ROOT_PART}" /mnt
mkdir -p /mnt/boot
mount "${EFI_PART}" /mnt/boot

# ---------- now proceed with the normal basestrap/chroot steps ----------
echoblue "Installing base system (basestrap)"
basestrap /mnt base base-devel runit linux linux-firmware grub efibootmgr dosfstools sudo networkmanager networkmanager-runit dbus-runit openssh vim

echoblue "Generating fstab"
fstabgen -U /mnt >> /mnt/etc/fstab

echoblue "Adding Arch mirrorlist placeholder and appending repo blocks"
if command -v wget >/dev/null 2>&1; then
  wget -q "https://archlinux.org/mirrorlist/all/" -O /mnt/etc/pacman.d/mirrorlist-arch || true
else
  echored "wget not present; mirrorlist-arch not downloaded (add it manually inside the installed system)."
fi

cat >> /mnt/etc/pacman.conf <<'EOF'

# === Arch repositories (added by install script) ===
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

echoblue "Chrooting to finalize configuration"
if command -v artix-chroot >/dev/null 2>&1; then
  CHROOT_CMD="artix-chroot /mnt /bin/bash -e -c"
else
  CHROOT_CMD="arch-chroot /mnt /bin/bash -e -c"
fi

${CHROOT_CMD} "set -euo pipefail
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

echo root:${PASSWORD} | chpasswd
useradd -m -G wheel -s /bin/bash '${USERNAME}' || true
echo '${USERNAME}:${PASSWORD}' | chpasswd || true
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers || true

# enable dbus and NetworkManager runit services
mkdir -p /etc/runit/runsvdir/default
ln -sf /etc/runit/sv/dbus /etc/runit/runsvdir/default/dbus || true
ln -sf /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager || true

# start them for configuration within chroot
mkdir -p /run/runit/service
ln -sf /etc/runit/sv/dbus /run/runit/service/dbus || true
ln -sf /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager || true

pacman -Syy --noconfirm
pacman -S --noconfirm --needed git base-devel

# try building paru as regular user
su - '${USERNAME}' -c 'cd /tmp && git clone https://aur.archlinux.org/paru.git || true && cd paru && makepkg -si --noconfirm || true'

# Install GRUB (UEFI)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Artix --recheck || true
grub-mkconfig -o /boot/grub/grub.cfg || true

# optionally enable ssh
ln -sf /etc/runit/sv/sshd /etc/runit/runsvdir/default/sshd || true

exit
"

echoblue "Final cleanup: unmounting and finishing"
if [ -n "${SWAP_PART}" ]; then
  swapoff "${SWAP_PART}" || true
fi

umount -R /mnt || true

echoblue "Done. Remove live media and reboot into your new system."