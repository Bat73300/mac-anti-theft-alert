#!/bin/zsh
# LaunchAgent entry point. It records each power state and triggers Shortcuts
# exactly once for a battery-to-AC transition allowed by the selected mode.
set -u
set -o pipefail

alert_dir="$HOME/.mac-alert"
state_file="$alert_dir/power-source"
temp_file="${state_file}.$$"
config_file="$alert_dir/config"
lock_state_file="$alert_dir/session-lock-state"
alert_mode="always"
shortcut_name="Mac Anti-Theft Alert"

if [[ -r "$config_file" ]]; then
  source "$alert_dir/mac-alert-common.sh"
  load_config "$config_file" || exit 1
  alert_mode="$ALERT_MODE"
  shortcut_name="$SHORTCUT_NAME"
fi

screen_state="unknown"
if [[ -r "$lock_state_file" ]]; then
  IFS= read -r screen_state < "$lock_state_file" || true
fi

if [[ "${1:-}" == "--status" ]]; then
  print -- "screen=$screen_state mode=$alert_mode"
  exit 0
fi

case "$alert_mode" in
  off)
    # Defense in depth: the mode selector unloads this agent, but an already
    # launched instance must also exit before checking power or retrying data.
    exit 0
    ;;
  always|locked_only) ;;
  *)
    print -u2 -- "mac-alert: ALERT_MODE must be always, locked_only, or off"
    exit 1
    ;;
esac

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
  if [[ "$alert_mode" == "locked_only" && "$screen_state" != "locked" ]]; then
    # Preserve the current power state but intentionally do not alert.
    exit 0
  fi
  # Run through Shortcuts so macOS applies its camera permission. Mail.app
  # permission is used only by the optional mail_app delivery mode.
  exec /usr/bin/shortcuts run "$shortcut_name"
fi
