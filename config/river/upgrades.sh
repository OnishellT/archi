#!/usr/bin/bash
sudo pacman -Syu

if command -v flatpak >/dev/null 2>&1; then
    # Running Flatpak
    sudo flatpak update
fi

# clear && exit

