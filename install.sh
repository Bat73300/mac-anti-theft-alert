#!/bin/zsh
# Installs the scripts and the LaunchAgent for the current macOS user.
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
alert_dir="$HOME/.mac-alert"
agent_dir="$HOME/Library/LaunchAgents"
label="com.example.mac-alert-power"
plist="$agent_dir/$label.plist"

if ! command -v imagesnap >/dev/null 2>&1; then
  print -u2 -- "imagesnap is required. Install it first with: brew install imagesnap"
  exit 1
fi

install -d -m 700 "$alert_dir" "$alert_dir/pending" "$agent_dir"
install -m 700 "$script_dir/mac-alert.sh" "$alert_dir/mac-alert.sh"
install -m 700 "$script_dir/mac-alert-queue.sh" "$alert_dir/mac-alert-queue.sh"
install -m 700 "$script_dir/mac-alert-power-watch.sh" "$alert_dir/mac-alert-power-watch.sh"

if [[ ! -f "$alert_dir/config" ]]; then
  install -m 600 "$script_dir/config.example" "$alert_dir/config"
  print -- "Created $alert_dir/config. Edit it before enabling the LaunchAgent."
else
  /bin/chmod 600 "$alert_dir/config"
fi

/usr/bin/sed "s|__HOME__|$HOME|g" "$script_dir/com.example.mac-alert-power.plist" > "$plist"
/bin/chmod 600 "$plist"

print -- "Installation files are ready."
print -- "1. Edit $alert_dir/config with your Telegram token, chat ID, and email address."
print -- "2. Create the Shortcuts shortcut described in README.md."
print -- "3. Re-run this command with --enable."

if [[ "${1:-}" == "--enable" ]]; then
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$label" 2>/dev/null || true
  /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$plist"
  print -- "LaunchAgent enabled: it checks power every 60 seconds."
fi
