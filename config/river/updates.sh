#!/usr/bin/env bash

let updates=0
let flats=0

# Get pacman updates
updates=$(pacman -Su --print | grep -Ec "^http")


if command -v flatpak >/dev/null 2>&1; then
     # Running Flatpak
      flats=$(flatpak update 2>/dev/null | tail -n +5 | grep -Ecv "^$|^Proceed|^Nothing")
      if [ -n $flats ] && [ -n $updates ]; then
          updates=$(($updates+$flats))
      fi
fi
 
echo "$updates"

