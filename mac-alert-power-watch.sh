#!/bin/zsh
# Run by launchd. Sends one alert when power changes from battery to AC.
set -u
set -o pipefail

alert_dir="$HOME/.mac-alert"
state_file="$alert_dir/power-source"
temp_file="${state_file}.$$"

current=$(/usr/bin/pmset -g batt 2>/dev/null | /usr/bin/awk -F"'" '/Now drawing from/{print $2; exit}')
case "$current" in
  "AC Power") current="ac" ;;
  *) current="battery" ;;
esac

previous=""
if [[ -r "$state_file" ]]; then
  IFS= read -r previous < "$state_file" || true
fi

# Try any Telegram alerts that were queued while the Mac was offline.
"$alert_dir/mac-alert-queue.sh" || true

umask 077
print -r -- "$current" > "$temp_file"
/bin/mv -f "$temp_file" "$state_file"

# Do not alert at service installation or login; only react to a change.
if [[ "$previous" == "battery" && "$current" == "ac" ]]; then
  # Run through Shortcuts so macOS applies its Camera and Mail permissions.
  exec /usr/bin/shortcuts run "Mac Anti-Theft Alert"
fi
