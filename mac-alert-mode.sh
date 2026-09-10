#!/bin/zsh
# Small user-facing selector for alert modes. Off unloads both project
# LaunchAgents; the other choices load them again without changing credentials.
set -eu

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
source "$alert_dir/mac-alert-common.sh"

if [[ ! -r "$config_file" ]]; then
  print -u2 -- "mac-alert: Configuration not found: $config_file"
  exit 1
fi

load_config "$config_file" || exit 1

choice=$(/usr/bin/osascript <<'APPLESCRIPT'
set options to {"Always — alert when the session is open or locked", "Locked only — alert only at the lock screen", "Off — disable monitoring and delivery"}
set pickedChoice to choose from list options with title "Mac Anti-Theft Alert" with prompt "Choose when power alerts may run:" default items {item 1 of options} OK button name "Save" cancel button name "Cancel"
if pickedChoice is false then return "cancelled"
return item 1 of pickedChoice
APPLESCRIPT
)

case "$choice" in
  "Always"*) new_mode="always" ;;
  "Locked only"*) new_mode="locked_only" ;;
  "Off"*) new_mode="off" ;;
  cancelled) exit 0 ;;
  *)
    print -u2 -- "mac-alert: No alert mode was selected"
    exit 1
    ;;
esac

temporary_file="${config_file}.$$"
if /usr/bin/grep -q '^ALERT_MODE=' "$config_file"; then
  /usr/bin/sed "s/^ALERT_MODE=.*/ALERT_MODE='$new_mode'/" "$config_file" > "$temporary_file"
else
  /bin/cp "$config_file" "$temporary_file"
  print -- "" >> "$temporary_file"
  print -- "ALERT_MODE='$new_mode'" >> "$temporary_file"
fi
/bin/chmod 600 "$temporary_file"
/bin/mv -f "$temporary_file" "$config_file"

uid=$(/usr/bin/id -u)
agent_dir="$HOME/Library/LaunchAgents"
power_label="com.example.mac-alert-power"
lock_label="com.example.mac-alert-lock-state"

if [[ "$new_mode" == off ]]; then
  # Stop periodic power checks, retry delivery, and lock-state observation.
  /bin/launchctl bootout "gui/$uid/$power_label" 2>/dev/null || true
  /bin/launchctl bootout "gui/$uid/$lock_label" 2>/dev/null || true
  print -- "mac-alert: Monitoring and delivery are disabled."
  exit 0
fi

# Re-enable both agents after Off. The lock monitor starts with an unknown
# state, so locked-only mode continues to fail closed until a new lock event.
for label in "$lock_label" "$power_label"; do
  plist="$agent_dir/$label.plist"
  if ! /bin/launchctl print "gui/$uid/$label" >/dev/null 2>&1; then
    /bin/launchctl bootstrap "gui/$uid" "$plist"
  fi
done
print -- "mac-alert: Alert mode saved as $new_mode"
