#!/usr/bin/env bash
set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────
# choices: key ↔ display text ↔ action
declare -A DISPLAY=(
  [shutdown]="  Shut down"
  [reboot]="  Reboot"
  [suspend]="  Suspend"
  [hibernate]="󰒲  Hibernate"
  [logout]="  Log out"
  [lockscreen]="  Lock screen"
)
declare -A ACTION=(
  [shutdown]="systemctl poweroff"
  [reboot]="systemctl reboot"
  [suspend]="systemctl suspend"
  [hibernate]="systemctl hibernate"
  [logout]="loginctl terminate-session ${XDG_SESSION_ID-}"
  [lockscreen]="loginctl lock-session ${XDG_SESSION_ID-}"
)
# Which actions need an extra “Are you sure?” step?
CONFIRM=(shutdown reboot logout)

# fzf options
FZF_OPTS=(
  --ansi
  --prompt=" Power→ "
  --height=20%
  --layout=reverse
  --border
)

# ── MAIN ───────────────────────────────────────────────────────────────────

# 1) build the menu
menu_items=()
for key in "${!DISPLAY[@]}"; do
  menu_items+=("${DISPLAY[$key]}ⱽ$key")
done

# 2) run fzf
selection=$(
  printf "%s\n" "${menu_items[@]}" |
  sed 's/ⱽ/ /' |
  fzf "${FZF_OPTS[@]}" --with-nth=1,2 \
      --preview="echo {}" \
      --preview-window=down:1:hidden
)

# if nothing chosen, exit
[[ -z "$selection" ]] && exit 0

# extract the key (second column)
key=$(awk '{print $2}' <<< "$selection")

# if needs confirmation, ask again
if printf '%s\n' "${CONFIRM[@]}" | grep -qx "$key"; then
  confirm=$(printf "Yes\nNo" | fzf --prompt="Confirm ${DISPLAY[$key]}? " --height=10% --layout=reverse --border)
  [[ "$confirm" != "Yes" ]] && exit 0
fi

# finally, run the action
eval "${ACTION[$key]}"

