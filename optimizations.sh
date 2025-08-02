
#!/bin/bash

# Add to existing script after hardware selection

### BOOT OPTIMIZATIONS ###
# Update GRUB configuration
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=0 console=tty2 udev.log_level=0 vt.global_cursor_default=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/' /etc/default/grub

# Remove Artix boot logo
rm -f /etc/issue

# Install rEFInd (optional)
read -p "Install rEFInd boot manager? (y/n): " refind_choice
if [[ "$refind_choice" == "y" ]]; then
    pacman -S --noconfirm refind
    refind-install --usedefault /dev/nvme0n1
fi

### FILESYSTEM OPTIMIZATIONS ###
# Apply noatime and fsck optimizations
sed -i 's/defaults/noatime,commit=60/' /etc/fstab
sed -i 's/0 [0-9]$/0 0/' /etc/fstab  # Disable fsck

### POWER MANAGEMENT ###
# Install TLP and Powertop
pacman -S --noconfirm tlp tlp-s6 powertop
echo 'powertop --auto-tune' >> /etc/rc.local

# Configure USB autosuspend
for usb in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
    echo 60000 > "$usb"
done

### PERFORMANCE SERVICES ###
pacman -S --noconfirm ananicy-cpp ananicy-cpp-s6 thermald thermald-s6 preload

# Configure Ananicy
s6-service add default ananicy-cpp

# Configure Thermald
s6-service add default thermald

# Configure Preload
echo 'preload' >> /etc/rc.local

### SECURITY SERVICES ###
pacman -S --noconfirm usbguard usbguard-s6

# Configure USBGuard
s6-service add default usbguard
usbguard generate-policy > /etc/usbguard/rules.conf
systemctl restart usbguard

### GRAPHICS OPTIMIZATIONS ###
# Intel GPU tweaks
echo 'options i915 enable_guc=2 enable_dc=4 fastboot=1' > /etc/modprobe.d/i915.conf

# NVIDIA Optimus Manager (if NVIDIA GPU)
if [[ "$choice" =~ ^(5|6)$ ]]; then
    pacman -S --noconfirm optimus-manager optimus-manager-s6
    s6-service add default optimus-manager
fi

### BROWSER OPTIMIZATION ###
pacman -S --noconfirm profile-sync-daemon psd-s6
s6-service add default psd

### COLOR MANAGEMENT ###
pacman -S --noconfirm colord colord-s6
s6-service add default colord

### FINAL OPTIMIZATIONS ###
# Remove fallback images
rm -f /boot/*fallback*

# Clean up services
s6-db-reload

# Rebuild initramfs
booster generate

echo "All optimizations applied successfully!"
