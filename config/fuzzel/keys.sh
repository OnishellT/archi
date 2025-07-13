#!/bin/sh

grep -E '^riverctl map ' "$HOME/.config/river/init" \
  | awk -F'#' '
    NF < 2 { next }  # skip if no comment

    {
      # Split pre-comment part into words
      n = split($1, parts, " ")

      # Extract only modifier and key (4th and 5th fields)
      # Avoid collecting the command
      keys = parts[4]
      if (n >= 5 && parts[5] !~ /^(spawn|close|toggle-|enter-mode|send-|set-|xdg-|bash)/)
        keys = keys " " parts[5]

      gsub(/^[ \t]+|[ \t]+$/, "", keys)
      gsub(/^[ \t]+|[ \t]+$/, "", $2)

      printf "%-20s → %s\n", keys, $2
    }
  ' | fuzzel --dmenu --prompt 'Keybind :> ' --match-mode=fuzzy --no-icons -w 80

