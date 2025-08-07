#!/bin/sh
# Install script for my dotfiles (minidots) - Artix Dinit Compatible

# Text color variables for styling
CR='\033[0;31m'; CG='\033[0;32m'; CY='\033[0;36m'; CB='\033[0;34m'; CRE='\033[0m'

# Exit if script is ran as root
[ "$(id -u)" -ne 0 ] || {
  printf "${CR}Do not run this script with root privileges! Exiting...${CRE}\n"
  exit 1
}

# Check if we're on Artix
if ! grep -q "Artix" /etc/os-release; then
  printf "${CR}This script is specifically designed for Artix Linux with dinit!${CRE}\n"
  printf "${CB}For other distributions, use the original script.${CRE}\n"
  exit 1
fi

# Check if dinit is available
if ! command -v dinitctl >/dev/null; then
  printf "${CR}Dinit not found! This script requires Artix with dinit.${CRE}\n"
  exit 1
fi

# Alias sudo to installed sudo util (prefer doas on Artix)
command -v doas >/dev/null && alias sudo="doas --" || {
  command -v sudo >/dev/null || { 
    command -v ssu >/dev/null && alias sudo="ssu -p --"
  }
}

# Modify system configs
printf "${CB}Editing system configuration files for Artix dinit...${CRE}\n"
{
  # Configure doas (preferred on Artix)
  if command -v doas >/dev/null; then
    sudo sh -c "printf '# Allow wheel group with password persistence\npermit persist :wheel\n# Allow wheel group without password (uncomment if needed)\n# permit nopass :wheel\n' > /etc/doas.conf"
    printf "${CB}Configured doas for wheel group${CRE}\n"
  elif command -v sudo >/dev/null; then
    sudo sed -i 's/^#\s*\(%wheel ALL=(ALL:ALL) ALL\)/\1/; s/^#\s*\(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers
    printf "${CB}Configured sudo for wheel group${CRE}\n"
  fi

  # Configure dinit auto-login on tty1
  if [ -f /etc/dinit.d/tty1 ]; then
    sudo sed -i "s|^\(command[[:space:]]*=[[:space:]]*/usr/lib/dinit/agetty-default\)|\1 -a $USER|" /etc/dinit.d/tty1
    printf "${CB}Configured dinit auto-login for $USER on tty1${CRE}\n"
  fi

  # Configure GRUB
  if command -v grub-mkconfig >/dev/null; then
    sudo sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/; s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/; s/^#\s*\(GRUB_SAVEDEFAULT=true\)/\1/' /etc/default/grub
    printf "${CB}Configured GRUB settings${CRE}\n"
  fi

  # Configure makepkg for better compilation
  if command -v pacman >/dev/null; then
    if ! grep -q "MAKEFLAGS" /etc/makepkg.conf; then
      sudo tee -a /etc/makepkg.conf <<EOF >/dev/null

# Custom compilation flags for better performance
COMMON_FLAGS="-O2 -march=native -pipe -flto"
export CFLAGS="\$COMMON_FLAGS"
export CXXFLAGS="\$COMMON_FLAGS"
export LDFLAGS="\$COMMON_FLAGS"
export FCFLAGS="\$COMMON_FLAGS"
export FFLAGS="\$COMMON_FLAGS"
export MAKEFLAGS="-j\$(nproc)"
EOF
      printf "${CB}Configured makepkg compilation flags${CRE}\n"
    fi
  fi
} && printf "${CG}Successfully edited system configs for Artix dinit${CRE}\n"

# Artix specific setup
printf "${CB}Setting up Artix-specific configurations...${CRE}\n"
{
  # Enable arch mirrors for access to AUR and additional packages
  printf "${CB}Setting up ${CY}arch-mirrors${CB} for pacman...${CRE}\n"
  sudo pacman -Syu --noconfirm artix-archlinux-support
  
  # Add arch repositories if not already present
  if ! grep -q "mirrorlist-arch" /etc/pacman.conf; then
    sudo tee -a /etc/pacman.conf <<EOF >/dev/null

# Arch repositories for additional packages
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    printf "${CB}Added Arch repositories to pacman.conf${CRE}\n"
  fi
  
  # Update package database
  sudo pacman -Sy
  
  # Install yay AUR helper
  if ! command -v yay >/dev/null; then
    printf "${CB}Installing ${CY}yay${CB} (AUR helper)...${CRE}\n"
    sudo pacman -S --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay-bin.git
    (cd yay-bin/ && makepkg -si --noconfirm)
    rm -rf yay-bin
    printf "${CG}Successfully installed yay${CRE}\n"
  fi
} && printf "${CG}Successfully completed Artix-specific setup${CRE}\n"

# Install packages
printf "${CB}Installing packages...${CRE}\n"
if [ -f ./pkg-list.sh ]; then
  sh ./pkg-list.sh && printf "${CG}Successfully installed all packages${CRE}\n"
else
  printf "${CY}pkg-list.sh not found, skipping package installation${CRE}\n"
fi

# Enable dinit services
printf "${CB}Enabling ${CY}dinit${CB} services for Artix...${CRE}\n"
{
  # System services
  printf "${CB}Enabling system services...${CRE}\n"
  for service in NetworkManager bluetoothd dbus turnstiled; do
    if [ -f "/etc/dinit.d/$service" ]; then
      sudo dinitctl enable "$service"
      printf "${CB}Enabled $service${CRE}\n"
    else
      printf "${CY}Service $service not found, skipping${CRE}\n"
    fi
  done
  
  # User services (copy custom service files if they exist)
  if [ -d ./services ]; then
    printf "${CB}Setting up user services...${CRE}\n"
    sudo mkdir -p /etc/dinit.d/user/
    for service in mpd syncthing easyeffects; do
      if [ -f "./services/$service" ]; then
        sudo cp "./services/$service" /etc/dinit.d/user/
        printf "${CB}Copied user service: $service${CRE}\n"
      fi
    done
  fi
  
  # Enable essential dinit services that might not be enabled by default
  for service in dbus; do
    if [ -f "/etc/dinit.d/$service" ]; then
      sudo dinitctl enable "$service"
      printf "${CB}Ensured $service is enabled${CRE}\n"
    fi
  done
} && printf "${CG}Successfully enabled dinit services${CRE}\n"

# Install themes
printf "${CB}Installing ${CY}gtk and cursor themes${CB}...${CRE}\n"
{
  # Clean up existing gtk-4.0 config
  rm -rf ~/.config/gtk-4.0/
  mkdir -p ~/.config
  
  # Install custom theme if available
  if [ -d ./minidark ]; then
    sudo cp -r ./minidark /usr/share/themes
    ln -s /usr/share/themes/minidark/gtk-4.0/ ~/.config/
    printf "${CB}Installed minidark theme${CRE}\n"
  fi
  
  # Configure papirus folders if available
  if command -v papirus-folders >/dev/null; then
    papirus-folders -C nordic
    printf "${CB}Configured papirus folders${CRE}\n"
  fi
  
  # Set default cursor theme
  sudo mkdir -p /usr/share/icons/default/
  sudo tee /usr/share/icons/default/index.theme <<EOF >/dev/null
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF
  printf "${CB}Set default cursor theme${CRE}\n"
} && printf "${CG}Successfully installed themes${CRE}\n"

# Stow dotfiles
printf "${CB}Linking ${CY}dotfiles${CB} with GNU Stow...${CRE}\n"
{
  # Create necessary directories
  dir_list=".local/src .local/share/mpd/playlists .config/spicetify .config/ncmpcpp .cache/wal .cache/script-cache"
  for i in $dir_list; do
    dir="$HOME/$i"
    mkdir -p "$dir" && printf "${CB}Created $dir${CRE}\n"
  done
  
  # Remove conflicting files
  rm -f ~/.bash* ~/.inputrc
  
  # Stow dotfiles (assuming we're in the dotfiles directory)
  if command -v stow >/dev/null; then
    (cd .. && stow . 2>/dev/null) || {
      printf "${CY}Stow failed, trying direct copy method${CRE}\n"
      # Fallback: direct copy method
      cp -r ../.* ~/ 2>/dev/null || true
    }
    printf "${CB}Linked dotfiles${CRE}\n"
  else
    printf "${CR}GNU Stow not found! Install it first: sudo pacman -S stow${CRE}\n"
    return 1
  fi
} && printf "${CG}Successfully linked dotfiles${CRE}\n"

# Configure script-cache files
printf "${CB}Configuring ${CY}script-cache${CB} files...${CRE}\n"
{
  mkdir -p ~/.cache/script-cache
  
  # Graphic configuration (default to free drivers)
  printf "${CB}Configuring ${CY}graphic-command${CB} script...${CRE}\n"
  tee ~/.cache/script-cache/graphic-command <<EOF >/dev/null
#!/bin/sh
# Using open source drivers (modify if you have proprietary GPU drivers)
# For NVIDIA proprietary:
# sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia
# sudo modprobe nouveau
# For AMD/Intel: usually no action needed
echo "Using open source GPU drivers"
EOF
  printf "Open Source\ncustom" > ~/.cache/script-cache/graphic-info
  
  # Wallpaper and colorscheme defaults
  printf "${CB}Setting up ${CY}wallpaper${CB} and ${CY}colorscheme${CB} defaults...${CRE}\n"
  tee ~/.cache/script-cache/wallpaper <<EOF >/dev/null
export previous_wallpaper="\$HOME/minidots/extras/wall.png"
export wallpaper="\$HOME/minidots/extras/wall.png"
EOF
  printf "export colorscheme=custom-metal" > ~/.cache/script-cache/colorscheme
  
  # Make scripts executable
  for i in graphic-command graphic-info wallpaper colorscheme; do
    chmod +x "$HOME/.cache/script-cache/$i"
  done
} && printf "${CG}Successfully configured script-cache files${CRE}\n"

# Check wlroots version compatibility
printf "${CB}Checking wlroots compatibility...${CRE}\n"

# Check for wlroots-git or regular wlroots
WLROOTS_VERSION=""
if pacman -Qi wlroots-git >/dev/null 2>&1; then
  WLROOTS_VERSION=$(pacman -Qi wlroots-git | grep Version | awk '{print $3}' | cut -d'-' -f1)
  printf "${CB}Found wlroots-git version: ${CY}$WLROOTS_VERSION${CRE}\n"
elif pacman -Qi wlroots >/dev/null 2>&1; then
  WLROOTS_VERSION=$(pacman -Qi wlroots | grep Version | awk '{print $3}' | cut -d'-' -f1)
  printf "${CB}Found wlroots version: ${CY}$WLROOTS_VERSION${CRE}\n"
fi

# If no wlroots found or version mismatch, offer to install correct version
if [ -z "$WLROOTS_VERSION" ] || [ "$WLROOTS_VERSION" = "0.20" ]; then
  printf "${CY}Warning: dwl typically requires wlroots 0.19, but found version $WLROOTS_VERSION${CRE}\n"
  printf "${CB}Do you want to install wlroots-0.19-git for better compatibility? [y/N]: ${CRE}"
  read -r install_019
  case "$install_019" in
    [Yy]*)
      printf "${CB}Removing current wlroots and installing wlroots-0.19-git...${CRE}\n"
      # Remove current wlroots
      if pacman -Qi wlroots-git >/dev/null 2>&1; then
        yay -R --noconfirm wlroots-git
      fi
      if pacman -Qi wlroots >/dev/null 2>&1; then
        sudo pacman -R --noconfirm wlroots
      fi
      # Install wlroots 0.19
      yay -S --noconfirm wlroots-0.19-git || {
        printf "${CR}Failed to install wlroots-0.19-git, trying wlroots-0.19-mao-git...${CRE}\n"
        yay -S --noconfirm wlroots-0.19-mao-git || {
          printf "${CR}Failed to install wlroots 0.19. Continuing with current setup...${CRE}\n"
        }
      }
      WLROOTS_VERSION="0.19"
      ;;
    *)
      printf "${CB}Continuing with current wlroots version...${CRE}\n"
      ;;
  esac
fi

# Determine compatible dwl branch/repository based on wlroots version
case "$WLROOTS_VERSION" in
  0.18*)
    DWL_BRANCH="wlroots-0.18"
    DWL_REPO="https://codeberg.org/oceanicc/dwl.git"
    printf "${CB}Using dwl branch for wlroots 0.18${CRE}\n"
    ;;
  0.17*)
    DWL_BRANCH="wlroots-0.17" 
    DWL_REPO="https://codeberg.org/oceanicc/dwl.git"
    printf "${CB}Using dwl branch for wlroots 0.17${CRE}\n"
    ;;
  0.19*)
    DWL_BRANCH="main"
    DWL_REPO="https://codeberg.org/oceanicc/dwl.git"
    printf "${CB}Using dwl main branch for wlroots 0.19${CRE}\n"
    ;;
  0.20*)
    # For wlroots 0.20, try upstream dwl which might be more current
    DWL_BRANCH="main"
    DWL_REPO="https://codeberg.org/dwl/dwl.git"
    printf "${CB}Using upstream dwl main branch for wlroots 0.20${CRE}\n"
    ;;
  *)
    printf "${CY}Unknown wlroots version ($WLROOTS_VERSION), using upstream dwl main branch${CRE}\n"
    DWL_BRANCH="main"
    DWL_REPO="https://codeberg.org/dwl/dwl.git"
    ;;
esac

# Clone and compile programs
printf "${CB}Cloning and compiling programs...${CRE}\n"
{
  clone() { 
    local repo="$1"
    local dest="$2"
    local branch="$3"
    
    if [ -n "$dest" ]; then
      if [ -n "$branch" ]; then
        git clone --depth=1 -b "$branch" "$repo" "$dest" 2>/dev/null || \
        git clone --depth=1 "$repo" "$dest"
      else
        git clone --depth=1 "$repo" "$dest"
      fi
    else
      git clone --depth=1 "$repo"
    fi && printf "${CG}Successfully cloned ${CY}$repo${CRE}\n" || {
      printf "${CR}Failed to clone ${CY}$repo${CRE}\n"
      return 1
    }
  }
  
  # Clone configurations
  if [ ! -d "$HOME/.config/nvim" ]; then
    clone https://codeberg.org/oceanicc/comfynvim "$HOME/.config/nvim"
  fi
  
  if [ ! -d "$HOME/.config/shell/plugins/powerlevel10k" ]; then
    mkdir -p "$HOME/.config/shell/plugins"
    clone https://github.com/romkatv/powerlevel10k.git "$HOME/.config/shell/plugins/powerlevel10k"
  fi
  
  # Clone and compile source programs
  cd "$HOME/.local/src/" || { printf "${CR}Failed to enter .local/src${CRE}\n"; exit 1; }
  
  # Clone dwl with appropriate repository and branch for wlroots compatibility
  if [ ! -d "dwl" ]; then
    printf "${CB}Cloning dwl from ${CY}$DWL_REPO${CB} with branch ${CY}$DWL_BRANCH${CB}...${CRE}\n"
    clone "$DWL_REPO" "dwl" "$DWL_BRANCH" || {
      printf "${CY}Specific branch failed, trying main branch...${CRE}\n"
      clone "$DWL_REPO" "dwl" || {
        printf "${CY}oceanicc/dwl failed, trying upstream dwl...${CRE}\n"
        clone "https://codeberg.org/dwl/dwl.git" "dwl"
      }
    }
  fi
  
  # Clone other programs
  for repo in oceanicc/minibar sewn/wlock sewn/widle sewn/wfreeze; do
    prog_name=$(basename "$repo")
    if [ ! -d "$prog_name" ]; then
      clone "https://codeberg.org/$repo.git" "$prog_name" || continue
    fi
  done
  
  # Create color links for programs that need them
  if [ -d dwl ]; then
    ln -sf "$HOME/.cache/wal/colors.h" "$HOME/.local/src/dwl/colors.h"
  fi
  if [ -d mew ]; then
    ln -sf "$HOME/.cache/wal/colors.h" "$HOME/.local/src/mew/colors.h"
  fi
  
  # Compile programs
  printf "${CB}Compiling programs...${CRE}\n"
  for dir in wlock widle wfreeze minibar dwl mew; do
    if [ -d "$dir" ]; then
      printf "${CB}Compiling ${CY}$dir${CB}...${CRE}\n"
      (
        cd "$dir" || exit 1
        sudo make clean install 2>/dev/null || make clean install
        make clean 2>/dev/null || true
      ) && printf "${CG}Compiled ${CY}$dir${CRE}\n" || \
        printf "${CR}Failed to compile ${CY}$dir${CRE}\n"
    fi
  done
} && printf "${CG}Successfully set up programs${CRE}\n"

# Final system configuration
printf "${CB}Applying final system configurations...${CRE}\n"
{
  # Change /bin/sh to dash for better performance
  if command -v dash >/dev/null; then
    printf "${CB}Changing /bin/sh to ${CY}dash${CB}...${CRE}\n"
    sudo ln -sfT /usr/bin/dash /bin/sh
    printf "${CG}Changed shell to dash${CRE}\n"
  fi
  
  # Prompt for zsh shell change
  printf "${CB}Do you want to change the user shell to zsh? [y/N]: ${CRE}"
  read -r shell
  case "$shell" in
    [Yy]*)
      if command -v zsh >/dev/null; then
        printf "${CB}Changing user shell to ${CY}zsh${CB}...${CRE}\n"
        chsh -s "$(command -v zsh)"
        printf "${CG}Changed user shell to zsh${CRE}\n"
      else
        printf "${CR}zsh not found! Install it first.${CRE}\n"
      fi
      ;;
  esac
  
  # Add user to necessary groups for Artix dinit
  printf "${CB}Adding $USER to necessary groups...${CRE}\n"
  for grp in audio video input seat; do
    if getent group "$grp" >/dev/null 2>&1; then
      sudo usermod -aG "$grp" "$USER"
      printf "${CB}Added $USER to $grp group${CRE}\n"
    fi
  done
  
  # Regenerate GRUB config
  if command -v grub-mkconfig >/dev/null; then
    printf "${CB}Regenerating GRUB configuration...${CRE}\n"
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    printf "${CG}GRUB configuration updated${CRE}\n"
  fi
} && printf "${CG}Successfully applied final configurations${CRE}\n"

# Print completion message
printf "\n${CG}=================================${CRE}\n"
printf "${CG}Installation completed successfully!${CRE}\n"
printf "${CG}=================================${CRE}\n\n"
printf "${CB}Next steps:${CRE}\n"
printf "${CB}1. Reboot your system: ${CY}sudo reboot${CRE}\n"
printf "${CB}2. After rebooting, run any post-install scripts${CRE}\n"
printf "${CB}3. Log into your window manager${CRE}\n"
printf "${CB}4. Enjoy your new Artix dinit setup!${CRE}\n\n"

printf "${CY}Note: Some services may need manual configuration after reboot.${CRE}\n"
printf "${CY}Check dinit service status with: dinitctl list${CRE}\n"

exit 0
