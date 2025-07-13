#!/usr/bin/env bash
# Simple Bluetooth menu: power, scan→list devices, pairable, discoverable

BT="bluetoothctl"
DMENU="fuzzel --dmenu "

# Icons (nerd font)
IC_POWER_ON="󰂯"    # BT on  
IC_POWER_OFF="󰂲"   # BT off  
IC_PAIR_ON="󰍙"     # Pairable on  
IC_PAIR_OFF="󰍚"    # Pairable off  
IC_DISC_ON="󰌔"     # Discoverable on  
IC_DISC_OFF="󰌕"    # Discoverable off  
IC_CON=""         # Connected  

# Helpers to echo line + return code
power_line() {
  if $BT show | grep -q "Powered: yes"; then
    echo "$IC_POWER_ON  Power: on"; return 0
  else
    echo "$IC_POWER_OFF  Power: off"; return 1
  fi
}
pair_line() {
  if $BT show | grep -q "Pairable: yes"; then
    echo "$IC_PAIR_ON  Pairable: yes"; return 0
  else
    echo "$IC_PAIR_OFF  Pairable: no"; return 1
  fi
}
disc_line() {
  if $BT show | grep -q "Discoverable: yes"; then
    echo "$IC_DISC_ON  Discoverable: yes"; return 0
  else
    echo "$IC_DISC_OFF  Discoverable: no"; return 1
  fi
}

# Toggle funcs
toggle_power() {
  power_line >/dev/null && $BT power off || $BT power on
  sleep 0.5
}
toggle_pair() {
  pair_line >/dev/null && $BT pairable off || $BT pairable on
  sleep 0.5
}
toggle_disc() {
  disc_line >/dev/null && $BT discoverable off || $BT discoverable on
  sleep 0.5
}

# Submenu for a specific device
device_menu() {
  local dev_line="$1" mac=$(echo $dev_line | awk '{print $2}') name="${dev_line#* }"
  local con_line paired trusted

  $BT info $mac | grep -q "Connected: yes" && con_line="$IC_CON Disconnect" || con_line="Connect"
  [ $($BT info $mac | grep -q "Paired: yes"; echo $?) -eq 0 ] && paired="Unpair" || paired="Pair"

  options=("$con_line" "$paired" "Back")
  choice=$(printf '%s\n' "${options[@]}" | $DMENU)
  case "$choice" in
    Connect)   $BT connect   $mac; sleep .5; device_menu "$dev_line" ;;
    Disconnect)$BT disconnect $mac; sleep .5; device_menu "$dev_line" ;;
    Pair)      $BT pair      $mac; sleep .5; device_menu "$dev_line" ;;
    Unpair)    $BT remove    $mac; sleep .5; device_menu "$dev_line" ;;
    *)         return ;;
  esac
}

# Scan and show discovered devices
do_scan() {
  $BT scan on & pid=$!; sleep 5; kill $pid 2>/dev/null; $BT scan off
  mapfile -t devices < <($BT devices | awk '{$1=""; print substr($0,2)}')
  if [ ${#devices[@]} -eq 0 ]; then
    printf "No devices found.\n" | $DMENU >/dev/null
    return
  fi
  devices+=("Back")
  choice=$(printf '%s\n' "${devices[@]}" | $DMENU)
  [[ "$choice" == "Back" || -z "$choice" ]] && return
  # find full line (MAC + name)
  dev_line=$($BT devices | grep -F " $choice")
  [ -n "$dev_line" ] && device_menu "$dev_line"
}

# Main menu loop
while true; do
  pow=$(power_line); par=$(pair_line); dis=$(disc_line)
  options=("$pow" "Scan for Devices" "$par" "$dis" "Exit")
  choice=$(printf '%s\n' "${options[@]}" | $DMENU)
  case "$choice" in
    "$pow")   toggle_power ;;
    "Scan for Devices") do_scan ;;
    "$par")   toggle_pair ;;
    "$dis")   toggle_disc ;;
    "Exit")   break ;;
    *)        ;;  # redisplay on anything else
  esac
done

