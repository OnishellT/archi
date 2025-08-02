#!/usr/bin/env bash
set -euo pipefail
foot "$@" &
# give it just enough time to map and get focus…
sleep 0.1
# mark the current focused window as floating
riverctl toggle-float
