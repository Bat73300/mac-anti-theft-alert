#!/bin/zsh
# Retry Telegram alerts created while this Mac was offline.
set -u
set -o pipefail
umask 077

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
pending_dir="$alert_dir/pending"

[[ -r "$config_file" && -d "$pending_dir" ]] || exit 0
source "$config_file"
[[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]] || exit 0

/usr/sbin/scutil -r api.telegram.org | /usr/bin/grep -q Reachable || exit 0

for event_dir in "$pending_dir"/*(N/); do
  [[ -r "$event_dir/message.txt" ]] || continue
  message=$(< "$event_dir/message.txt")

  if [[ ! -e "$event_dir/message.sent" ]]; then
    /usr/bin/curl --fail --silent --show-error --max-time 20 \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=${message}" \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" >/dev/null || continue
    : > "$event_dir/message.sent"
  fi

  if [[ -f "$event_dir/photo.jpg" && ! -e "$event_dir/photo.sent" ]]; then
    /usr/bin/curl --fail --silent --show-error --max-time 30 \
      -F "chat_id=${TELEGRAM_CHAT_ID}" \
      -F "caption=${message}" \
      -F "photo=@${event_dir}/photo.jpg" \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" >/dev/null || continue
    : > "$event_dir/photo.sent"
  fi

  /bin/rm -rf -- "$event_dir"
done
