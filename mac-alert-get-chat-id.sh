#!/bin/zsh
# One-time setup helper: retrieves the intended private chat ID from a unique
# phrase the owner has just sent to their bot. It avoids accidentally selecting
# the bot ID or another person's message from the Telegram update history.
set -eu

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
source "$alert_dir/mac-alert-common.sh"

load_config "$config_file"
[[ -n "$TELEGRAM_BOT_TOKEN" ]] || { print -u2 -- "mac-alert: Set TELEGRAM_BOT_TOKEN first"; exit 1; }
[[ $# -eq 1 && -n "$1" ]] || {
  print -u2 -- "Usage: $0 'unique phrase sent to the bot'"
  exit 2
}
verification_phrase="$1"
response_file="$(/usr/bin/mktemp "$alert_dir/.telegram-updates.XXXXXX")"
trap '/bin/rm -f -- "$response_file"' EXIT

{
  print -- 'silent'
  print -- 'fail'
  print -- 'connect-timeout = 5'
  print -- 'max-time = 20'
  curl_config_line url "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates"
} | /usr/bin/curl --config - > "$response_file"

/usr/bin/python3 "$alert_dir/mac-alert-select-chat-id.py" "$response_file" "$verification_phrase"
