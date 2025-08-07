### **Complete Guide: Installing Labwc and Yambar on Artix Linux (s6)**

This guide covers installing **Labwc** (a stacking Wayland compositor) and **Yambar** (status panel) on Artix Linux using the **s6 init system**. Both tools prioritize minimalism and performance.

---

### **1. System Preparation**
```bash
# Update system
sudo artix-upgrade

# Install essential dependencies
sudo pacman -S base-devel git meson ninja scdoc wayland wayland-protocols wlroots libxkbcommon cairo pango
```

---

### **2. Install Labwc**
#### **Install Dependencies**
```bash
sudo pacman -S seatd libxml2 glib2
```

#### **Build and Install Labwc**
```bash
git clone https://github.com/labwc/labwc.git
cd labwc
meson setup build
ninja -C build
sudo ninja -C build install
```

#### **Enable Seatd with s6**
```bash
# Add to default bundle
sudo s6-rc-bundle add seatd default

# Enable immediately
sudo s6-rc -u change seatd

# Add user to seat group
sudo usermod -aG seat $USER  # Replace $USER with your username
```
**Reboot** to apply changes.

---

### **3. Install Yambar**
#### **Install Dependencies**
```bash
sudo pacman -S libudev-zero pixman
```

#### **Build and Install Yambar**
```bash
git clone https://codeberg.org/dnkl/yambar
cd yambar
meson setup build
ninja -C build
sudo ninja -C build install
```

---

### **4. Configure Labwc**
#### **Create Config Directory**
```bash
mkdir -p ~/.config/labwc
```

#### **Basic `rc.xml` (Window Manager Config)**
Create `~/.config/labwc/rc.xml`:
```xml
<?xml version="1.0"?>
<labwc_config>
  <core>
    <gap>10</gap>
  </core>
  <keyboard>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="A-Tab">
      <action name="NextWindow"/>
    </keybind>
    <keybind key="W-Return">
      <action name="Execute">
        <command>foot</command>
      </action>
    </keybind>
  </keyboard>
  <theme>
    <name>default</name>
    <cornerRadius>8</cornerRadius>
  </theme>
</labwc_config>
```

#### **Autostart Yambar**
```bash
mkdir -p ~/.config/labwc/autostart
echo 'yambar &' > ~/.config/labwc/autostart/yambar.sh
chmod +x ~/.config/labwc/autostart/yambar.sh
```

---

### **5. Configure Yambar**
Create `~/.config/yambar/config.yml`:
```yaml
bar:
  height: 26
  location: top
  background: 282828
  foreground: ebdbb2

  contents:
    left:
      - clock:
          format: "%H:%M %a %d/%m"
          foreground: 83a598
    right:
      - battery:
          adapters: BAT0
          format: {string: "{capacity}% {icon}"}
          icons:
            - {range: [0, 10], string: ""}
            - {range: [10, 40], string: ""}
            - {range: [40, 70], string: ""}
            - {range: [70, 95], string: ""}
            - {range: [95, 100], string: ""}
```

Test configuration:  
```bash
yambar --log-level=debug
```

---

### **6. Start Labwc**
#### **From TTY:**
```bash
dbus-run-session labwc
```

#### **With Autologin (s6):**
1. Edit `/etc/s6/sv/agetty-tty1/run`:
   ```bash
   # Replace the exec line with:
   exec agetty --autologin YOUR_USERNAME --noclear tty1
   ```
2. Create `~/.profile` with:
   ```bash
   if [ "$(tty)" = "/dev/tty1" ]; then
       exec dbus-run-session labwc
   fi
   ```

---

### **7. Essential s6 Management**
| Command | Description |
|---------|-------------|
| `sudo s6-rc -l` | List all services |
| `sudo s6-rc -d change seatd` | Temporarily disable seatd |
| `sudo s6-rc -u change seatd` | Re-enable seatd |
| `sudo s6-rc-db-reload` | Reload service database |

---

### **8. Troubleshooting**
#### **Common Issues:**
1. **Seatd not running:**
   ```bash
   sudo s6-rc -u change seatd
   groups | grep seat  # Verify user in seat group
   ```

2. **Wayland session failures:**
   ```bash
   rm -r ~/.local/share/labwc/  # Reset compositor state
   ```

3. **Yambar modules not working:**
   Check dependencies:
   ```bash
   sudo pacman -S upower networkmanager  # For battery/network modules
   ```

#### **Log Locations:**
- Labwc: `~/.local/share/labwc/labwc.log`
- Seatd: `/etc/s6/sv/seatd/logs/current`
- General s6 logs: `/etc/s6/sv/*/logs/current`

---

### **9. Uninstall**
```bash
# Labwc
sudo rm /usr/local/bin/labwc
rm -r ~/.config/labwc

# Yambar
sudo rm /usr/local/bin/yambar
rm -r ~/.config/yambar

# Remove seatd (optional)
sudo s6-rc-bundle delete seatd default
sudo pacman -R seatd
```

---

### **Recommended Additions**
1. **Terminal:** Install `foot` or `alacritty`
   ```bash
   sudo pacman -S foot
   ```
2. **App Launcher:** Install `fuzzel`
   ```bash
   sudo pacman -S fuzzel
   ```
   Add to `rc.xml`:
   ```xml
   <keybind key="A-d">
     <action name="Execute">
       <command>fuzzel</command>
     </action>
   </keybind>
   ```

3. **Theme Engine:** Install `nwg-look` for GTK theming
   ```bash
   sudo pacman -S nwg-look
   ```

---
### Adding Labwc to Xfce Login Manager (LightDM) on Artix Linux

To add Labwc as a session option in the Xfce login manager (typically LightDM), follow these steps:

#### 1. Create a Labwc Desktop Entry
Create a new session file in `/usr/share/wayland-sessions/`:
```bash
sudo nano /usr/share/wayland-sessions/labwc.desktop
```

Add this content:
```ini
[Desktop Entry]
Name=Labwc
Comment=Lightweight Stacking Wayland Compositor
Exec=dbus-run-session labwc
Type=Application
```

#### 2. Create Session Environment File
Create a wrapper script to set up the environment:
```bash
sudo nano /usr/local/bin/labwc-session
```

Add:
```bash
#!/bin/sh
export XDG_CURRENT_DESKTOP=Labwc
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland

exec dbus-run-session labwc "$@"
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/labwc-session
```

#### 3. Update Desktop Entry
Modify your `.desktop` file to use the wrapper:
```bash
sudo nano /usr/share/wayland-sessions/labwc.desktop
```

Change the `Exec` line to:
```ini
Exec=/usr/local/bin/labwc-session
```

#### 4. Create Session Icon (Optional)
For better visual identification:
```bash
sudo wget https://raw.githubusercontent.com/labwc/labwc/master/contrib/labwc.svg -O /usr/share/icons/labwc.svg
```

Then add to your desktop file:
```ini
Icon=labwc
```

#### 5. Update LightDM Configuration
Edit the LightDM configuration:
```bash
sudo nano /etc/lightdm/lightdm.conf
```

Ensure these lines exist under `[Seat:*]`:
```ini
greeter-session=lightdm-greeter
session-directory=/usr/share/wayland-sessions:/usr/share/xsessions
```

#### 6. Restart LightDM
Apply changes:
```bash
sudo s6-rc -d change lightdm  # Stop
sudo s6-rc -u change lightdm  # Start
```

### Verify the Setup
1. At the login screen, click the session selector (usually a gear icon)
2. You should see "Labwc" listed as an available session
3. Select it and log in normally

### Troubleshooting
1. **If Labwc doesn't appear:**
   - Check desktop file location:
     ```bash
     ls /usr/share/wayland-sessions/
     ```
   - Verify file permissions:
     ```bash
     sudo chmod 644 /usr/share/wayland-sessions/labwc.desktop
     ```

2. **If session fails to start:**
   - Check logs:
     ```bash
     journalctl -u lightdm --since "5 minutes ago"
     ```
   - Test session manually from TTY:
     ```bash
     /usr/local/bin/labwc-session
     ```

3. **For GTK/Gnome users:** Install additional theming support
   ```bash
   sudo pacman -S xdg-desktop-portal xdg-desktop-portal-wlr
   ```

### Alternative: SDDM Display Manager
If using SDDM instead of LightDM:
1. Create the same `/usr/share/wayland-sessions/labwc.desktop` file
2. Install SDDM Wayland support:
   ```bash
   sudo pacman -S sddm sddm-wayland
   ```
3. Enable SDDM:
   ```bash
   sudo s6-rc-bundle add sddm default
   sudo s6-rc -u change sddm
   ```

### Final Notes
- This setup ensures Labwc appears as a dedicated Wayland session
- The wrapper script handles necessary environment variables
- You can customize the session name/icon by modifying `labwc.desktop`
- For additional polish, consider installing a login manager theme that supports Wayland sessions
