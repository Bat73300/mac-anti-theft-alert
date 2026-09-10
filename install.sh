#!/bin/zsh
# Installs the scripts and the LaunchAgent for the current macOS user.
# This is the only entry point users need: it creates the private directory,
# copies the helpers, compiles the lock monitor, and installs both agents.
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
alert_dir="$HOME/.mac-alert"
agent_dir="$HOME/Library/LaunchAgents"
label="com.example.mac-alert-power"
plist="$agent_dir/$label.plist"
lock_label="com.example.mac-alert-lock-state"
lock_plist="$agent_dir/$lock_label.plist"

case "${1:-}" in
  ''|--enable) ;;
  *) print -u2 -- "Usage: zsh install.sh [--enable]"; exit 2 ;;
esac

if ! command -v imagesnap >/dev/null 2>&1; then
  print -u2 -- "mac-alert: imagesnap is not installed; alerts will send without a photo."
  print -u2 -- "mac-alert: Install it later with: brew install imagesnap"
fi

install -d -m 700 "$alert_dir" "$alert_dir/pending" "$agent_dir"
install -m 700 "$script_dir/mac-alert.sh" "$alert_dir/mac-alert.sh"
install -m 700 "$script_dir/mac-alert-queue.sh" "$alert_dir/mac-alert-queue.sh"
install -m 700 "$script_dir/mac-alert-power-watch.sh" "$alert_dir/mac-alert-power-watch.sh"
install -m 700 "$script_dir/mac-alert-mode.sh" "$alert_dir/mac-alert-mode.sh"
install -m 700 "$script_dir/mac-alert-get-chat-id.sh" "$alert_dir/mac-alert-get-chat-id.sh"
install -m 700 "$script_dir/mac-alert-select-chat-id.py" "$alert_dir/mac-alert-select-chat-id.py"
install -m 700 "$script_dir/mac-alert-configure-gmail-smtp.sh" "$alert_dir/mac-alert-configure-gmail-smtp.sh"
install -m 700 "$script_dir/mac-alert-common.sh" "$alert_dir/mac-alert-common.sh"
install -m 700 "$script_dir/mac-alert-send-smtp.py" "$alert_dir/mac-alert-send-smtp.py"
/usr/bin/clang -fobjc-arc -framework Foundation \
  -o "$alert_dir/mac-alert-lock-state-monitor" \
  "$script_dir/mac-alert-lock-state-monitor.m"
/bin/chmod 700 "$alert_dir/mac-alert-lock-state-monitor"

if [[ ! -f "$alert_dir/config" ]]; then
  install -m 600 "$script_dir/config.example" "$alert_dir/config"
  print -- "Created $alert_dir/config. Edit it before enabling the LaunchAgent."
else
  /bin/chmod 600 "$alert_dir/config"
  if ! /usr/bin/grep -q '^SHORTCUT_NAME=' "$alert_dir/config"; then
    print -- "" >> "$alert_dir/config"
    print -- "# Exact name of the shortcut that sends the alert." >> "$alert_dir/config"
    print -- "SHORTCUT_NAME='Mac Anti-Theft Alert'" >> "$alert_dir/config"
  fi
fi

/usr/bin/sed "s|__HOME__|$HOME|g" "$script_dir/com.example.mac-alert-power.plist" > "$plist"
/bin/chmod 600 "$plist"
/usr/bin/sed "s|__HOME__|$HOME|g" "$script_dir/com.example.mac-alert-lock-state.plist" > "$lock_plist"
/bin/chmod 600 "$lock_plist"

print -- "Installation files are ready."
print -- "Privacy: alerts can send a webcam photo and network details to Telegram and email."
print -- "Next: follow docs/SETUP.md, then re-run this command with --enable."

if [[ "${1:-}" == "--enable" ]]; then
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$lock_label" 2>/dev/null || true
  /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$lock_plist"
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$label" 2>/dev/null || true
  /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$plist"
  print -- "LaunchAgent enabled: it checks power every 60 seconds."
fi
