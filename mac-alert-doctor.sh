#!/bin/zsh
# Read-only setup diagnostic. It validates the local configuration and reports
# which project dependencies are available without sending an alert, opening
# the camera, contacting the network, or reading a Keychain password.
set -u
set -o pipefail

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
agent_dir="$HOME/Library/LaunchAgents"
power_label="com.example.mac-alert-power"
lock_label="com.example.mac-alert-lock-state"
problems=0

report_ok() { print -- "OK    $1"; }
report_note() { print -- "NOTE  $1"; }
report_problem() { print -u2 -- "CHECK $1"; problems=1; }

[[ -r "$config_file" ]] || {
  report_problem "Configuration not found: $config_file"
  exit 1
}

source "$alert_dir/mac-alert-common.sh"
load_config "$config_file" || exit 1
report_ok "Private configuration is valid"

config_mode=$(/usr/bin/stat -f '%Lp' "$config_file")
if [[ "$config_mode" == 600 ]]; then
  report_ok "Configuration permissions are private (600)"
else
  report_problem "Configuration permissions are $config_mode; run: chmod 600 $config_file"
fi

if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
  report_ok "Telegram credentials are configured"
else
  report_problem "Telegram token or private chat ID is missing"
fi

if [[ -n "$EMAIL_TO" ]]; then
  report_ok "Email recipient is configured"
else
  report_problem "Email recipient is missing"
fi

case "$EMAIL_DELIVERY" in
  mail_app)
    report_note "Mail.app delivery is selected; send one manual test to confirm Mail.app permission"
    ;;
  smtp)
    report_ok "Direct SMTP delivery is selected"
    if python3_path="$(find_python3 2>/dev/null)"; then
      report_ok "Python 3 is available for direct SMTP: $python3_path"
    else
      report_problem "Python 3 is required for direct SMTP; install it with: brew install python"
    fi
    report_note "Run mac-alert-setup-test.sh to confirm Keychain access and SMTP delivery"
    ;;
esac

if [[ "$CAPTURE_PHOTO" == false ]]; then
  report_note "Camera capture is disabled in configuration"
elif (( $+commands[imagesnap] )); then
  report_ok "imagesnap is available for camera capture"
else
  report_problem "imagesnap is missing; alerts will be sent without a photo"
fi

if /usr/bin/shortcuts list 2>/dev/null | /usr/bin/grep -Fxq -- "$SHORTCUT_NAME"; then
  report_ok "Shortcut exists: $SHORTCUT_NAME"
  report_note "Run mac-alert-setup-test.sh once to confirm delivery and macOS privacy prompts"
else
  report_problem "Shortcut was not found: $SHORTCUT_NAME"
fi

uid=$(/usr/bin/id -u)
for label in "$power_label" "$lock_label"; do
  plist="$agent_dir/$label.plist"
  if /bin/launchctl print "gui/$uid/$label" >/dev/null 2>&1; then
    report_ok "LaunchAgent is loaded: $label"
  elif [[ "$ALERT_MODE" == off ]]; then
    report_note "LaunchAgent is intentionally disabled while mode is Off: $label"
  elif [[ -f "$plist" ]]; then
    report_problem "LaunchAgent is installed but not loaded: $label"
  else
    report_problem "LaunchAgent plist is missing: $label"
  fi

  if [[ -f "$plist" ]]; then
    plist_mode=$(/usr/bin/stat -f '%Lp' "$plist")
    if [[ "$plist_mode" == 600 ]]; then
      report_ok "LaunchAgent permissions are private: $label"
    else
      report_problem "LaunchAgent permissions are $plist_mode: $label"
    fi
  fi
done

lock_state="unknown"
[[ -r "$alert_dir/session-lock-state" ]] && IFS= read -r lock_state < "$alert_dir/session-lock-state" || true
if [[ "$ALERT_MODE" == locked_only && "$lock_state" == unknown ]]; then
  report_note "Lock the screen and sign back in once to initialize Locked only mode"
else
  report_ok "Current mode is $ALERT_MODE; screen state is $lock_state"
fi

if (( problems )); then
  print -u2 -- "mac-alert: Doctor found items to check. It did not send an alert."
  exit 1
fi
print -- "mac-alert: Doctor found no local setup problem. It did not send an alert."
