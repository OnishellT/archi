### **Complete Guide: Installing Labwc and Yambar on Artix Linux (runit)**

This guide covers installing **Labwc** (a lightweight stacking Wayland compositor) and **Yambar** (a minimal status panel) on Artix Linux with runit. Both tools prioritize simplicity and performance.

---

### **1. System Preparation**
Update your system and install essential dependencies:
```bash
sudo artix-upgrade
sudo pacman -S base-devel git meson ninja scdoc wayland wayland-protocols wlroots libxkbcommon cairo pango
```

---

### **2. Install Labwc**
#### **Dependencies**
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

#### **Enable Seatd (for seat management)**
```bash
sudo ln -s /etc/runit/sv/seatd /run/runit/service/
sudo sv start seatd
sudo usermod -aG seat $USER  # Replace `$USER` with your username
```
**Reboot** to apply group changes.

---

### **3. Install Yambar**
#### **Dependencies**
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
Create the configuration directory:
```bash
mkdir -p ~/.config/labwc
```

#### **Basic `rc.xml` Configuration**
Create `~/.config/labwc/rc.xml`:
```xml
<?xml version="1.0"?>
<labwc_config>
  <core>
    <gap>10</gap> <!-- Screen edge gap -->
  </core>
  <keyboard>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="A-Tab">
      <action name="NextWindow"/>
    </keybind>
  </keyboard>
  <theme>
    <name>default</name>
    <cornerRadius>8</cornerRadius>
  </theme>
</labwc_config>
```

#### **Autostart Yambar**
Create an autostart script:
```bash
mkdir -p ~/.config/labwc/autostart
echo 'yambar &' > ~/.config/labwc/autostart/yambar.sh
chmod +x ~/.config/labwc/autostart/yambar.sh
```

---

### **5. Configure Yambar**
#### **Basic Configuration**
Create `~/.config/yambar/config.yml`:
```yaml
bar:
  height: 24
  location: top
  background: 282828
  foreground: ebdbb2

  contents:
    - clock:
        format: "%a %d %b %H:%M"
        foreground: 83a598
```

#### **Test Yambar**
Run manually to verify:
```bash
yambar
```
Press `Ctrl+C` to exit.

---

### **6. Start Labwc**
#### **Option 1: Direct Launch (from TTY)**
```bash
dbus-run-session labwc
```

#### **Option 2: Display Manager**
If using a display manager (e.g., Ly), select `Labwc` from the session menu.

---

### **7. Essential Tips**
#### **Themes**
- Place window themes in `~/.local/share/themes` or `/usr/share/themes`.
- Example theme: [Arc-Dark](https://github.com/jnsh/arc-theme).

#### **Key Bindings**
Customize keybinds in `rc.xml`:
```xml
<keybind key="W-Return">
  <action name="Execute">
    <command>foot</command> <!-- Example: Launch terminal -->
  </action>
</keybind>
```

#### **Troubleshooting**
- **Labwc Logs:** Check `~/.local/share/labwc/labwc.log`.
- **Yambar Debug:** Run `yambar --log-level=debug`.
- **Wayland Issues:** Ensure `seatd` is running (`sv status seatd`).

---

### **8. Uninstall**
Remove built packages:
```bash
# Labwc
sudo rm /usr/local/bin/labwc  # If installed manually

# Yambar
sudo rm /usr/local/bin/yambar
```

---

### **Final Notes**
- **Explore Configs:** Customize `rc.xml` and `config.yml` further (see [Labwc Docs](https://github.com/labwc/labwc) and [Yambar Docs](https://codeberg.org/dnkl/yambar)).
- **Alternative Panels:** Consider [Waybar](https://github.com/Alexays/Waybar) if Yambar lacks features.
- **Artix Runit:** Use `sv` commands to manage `seatd` (start/stop/restart).

Enjoy your minimal Wayland setup!
