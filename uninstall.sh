#!/bin/zsh
# Removes every file and per-user LaunchAgent installed by this project.
# Use --purge-keychain as well to remove the SMTP app password stored under the
# project service name. It does not delete remote messages,
# Telegram bots, macOS logs, or Homebrew itself; see docs/UNINSTALL.md.
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
alert_dir="$HOME/.mac-alert"
agent_dir="$HOME/Library/LaunchAgents"
uid=$(/usr/bin/id -u)
power_label="com.example.mac-alert-power"
lock_label="com.example.mac-alert-lock-state"
purge_keychain=false
dry_run=false

for argument in "$@"; do
  case "$argument" in
    --purge-keychain) purge_keychain=true ;;
    --dry-run) dry_run=true ;;
    *) print -u2 -- "Usage: ./uninstall.sh [--dry-run] [--purge-keychain]"; exit 2 ;;
  esac
done

remove_file() {
  if [[ "$dry_run" == true ]]; then
    print -- "Would remove: $*"
  else
    /bin/rm -f -- "$@"
  fi
}

remove_directory() {
  if [[ "$dry_run" == true ]]; then
    print -- "Would remove directory: $1"
  else
    /bin/rm -rf -- "$1"
  fi
}

# Read the service before deleting the private directory. The shared parser
# treats config as data, so its contents are never executed. The service name
# is unique to this project; deleting by service avoids an account-name mismatch
# leaving the app password behind.
smtp_service=""
if [[ "$purge_keychain" == true && -r "$alert_dir/config" ]]; then
  source "$script_dir/mac-alert-common.sh"
  if load_config "$alert_dir/config"; then
    smtp_service="$SMTP_KEYCHAIN_SERVICE"
  else
    print -u2 -- "mac-alert: Could not read config; Keychain item was not removed."
  fi
fi

# Stop both per-user services before removing their plist files. `bootout` is
# deliberately tolerant because an agent may already be disabled.
if [[ "$dry_run" == true ]]; then
  print -- "Would stop: gui/$uid/$power_label"
  print -- "Would stop: gui/$uid/$lock_label"
else
  /bin/launchctl bootout "gui/$uid/$power_label" 2>/dev/null || true
  /bin/launchctl bootout "gui/$uid/$lock_label" 2>/dev/null || true
fi
remove_file "$agent_dir/$power_label.plist" "$agent_dir/$lock_label.plist"

if [[ "$purge_keychain" == true && -n "$smtp_service" ]]; then
  if [[ "$dry_run" == true ]]; then
    print -- "Would remove the matching SMTP Keychain item."
  else
    if /usr/bin/security delete-generic-password -s "$smtp_service" >/dev/null 2>&1; then
      print -- "mac-alert: Matching SMTP Keychain item removed."
    else
      print -u2 -- "mac-alert: Matching SMTP Keychain item was not found or could not be removed."
    fi
  fi
fi

# This directory contains the token, queue, captured photos, configuration,
# lock-state marker, and every helper copied during installation.
remove_directory "$alert_dir"
if [[ "$dry_run" == true ]]; then
  print -- "mac-alert: Dry run complete; nothing was removed."
  exit 0
fi
print -- "mac-alert: Project files and LaunchAgents removed."
if [[ "$purge_keychain" == true ]]; then
  print -- "mac-alert: Keychain removal was attempted; see the message above."
else
  print -- "mac-alert: SMTP Keychain item retained. Re-run with --purge-keychain to remove it."
fi
