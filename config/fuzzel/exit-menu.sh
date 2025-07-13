#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────

WALLPAPER="$HOME/.config/river/wallpapers/lock-wp.jpg"
LOCK_CMD="gtklock \
  --background \"$WALLPAPER\" \
  --style \"$HOME/.config/gtklock/themes/catppuccin-mocha/theme.css\" \
  --daemonize"

# fuzzel options (v1.11+)
FUZZEL_OPTS="--dmenu --match-mode=exact --launch-prefix=<not set>"

# Menu choices: Icon<TAB>Action  (using Nerd Font glyphs)
OPTIONS=(
  "	Lock"         # nf-fa-lock
  "	Suspend"      # nf-fa-moon-o
  "	Logout"       # nf-fa-sign-out
  "	Reboot"       # nf-md-power-cycle
  "	Shutdown"     # nf-fa-power-off
)

# ─── Show menu ────────────────────────────────────────────────────
CHOICE=$(printf "%s\n" "${OPTIONS[@]}" \
  | fuzzel $FUZZEL_OPTS --lines=5 --prompt "Select action:")
[[ -z "$CHOICE" ]] && exit 0
ACTION=$(awk '{print $2}' <<<"$CHOICE")

# ─── Confirm choice ───────────────────────────────────────────────
CONFIRM=$(printf "No - Cancel\nYes - Confirm\n" \
  | fuzzel $FUZZEL_OPTS --lines=2 --prompt "Confirm $ACTION?" \
  | awk '{print $1}')
[[ "$CONFIRM" != "Yes" ]] && exit 0

# ─── Execute ──────────────────────────────────────────────────────
case "$ACTION" in
  Lock)
    # expand and run the lock command
    eval $LOCK_CMD
    ;;
  Suspend)
    systemctl suspend
    ;;
  Logout)
    riverctl exit
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
esac

exit 0

