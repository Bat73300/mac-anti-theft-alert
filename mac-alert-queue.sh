#!/bin/zsh
# Background retry worker. The power watcher calls it once per minute to deliver
# private queued Telegram and SMTP alerts, then removes only fully delivered items.
set -u
set -o pipefail
umask 077

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
pending_dir="$alert_dir/pending"

source "$alert_dir/mac-alert-common.sh"

[[ -r "$config_file" && -d "$pending_dir" ]] || exit 0
load_config "$config_file" || exit 1
[[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]] || exit 0

prune_pending_alerts "$pending_dir"

telegram_available=false
# A bounded HTTPS probe prevents the periodic LaunchAgent from hanging on a
# route-resolution issue. The alert remains private in the queue if unavailable.
/usr/bin/curl --silent --show-error --output /dev/null \
  --connect-timeout 3 --max-time 5 https://api.telegram.org && telegram_available=true

for event_dir in "$pending_dir"/*(N/); do
  [[ -r "$event_dir/message.txt" ]] || continue
  telegram_complete=true
  if [[ ! -e "$event_dir/message.sent" ]]; then
    if [[ "$telegram_available" == true ]]; then
      telegram_message "$event_dir/message.txt" || telegram_complete=false
      if [[ "$telegram_complete" == true ]]; then
        : > "$event_dir/message.sent"
        /bin/chmod 600 "$event_dir/message.sent"
      fi
    else
      telegram_complete=false
    fi
  fi

  if [[ -f "$event_dir/photo.jpg" && ! -e "$event_dir/photo.sent" ]]; then
    if [[ "$telegram_available" == true ]]; then
      telegram_photo "$event_dir/photo.jpg" || telegram_complete=false
      if [[ "$telegram_complete" == true ]]; then
        : > "$event_dir/photo.sent"
        /bin/chmod 600 "$event_dir/photo.sent"
      fi
    else
      telegram_complete=false
    fi
  fi

  # Only SMTP needs an application-managed email retry. Mail.app manages its
  # own Outbox and is intentionally not invoked again from this queue.
  if [[ "$EMAIL_DELIVERY" == smtp && ! -e "$event_dir/mail.sent" ]]; then
    mac_name=$(/usr/sbin/scutil --get ComputerName 2>/dev/null || /bin/hostname)
    smtp_send "$event_dir/message.txt" "$event_dir/photo.jpg" "Mac Alert - ${mac_name}" || continue
    : > "$event_dir/mail.sent"
    /bin/chmod 600 "$event_dir/mail.sent"
  fi

  [[ "$telegram_complete" == true ]] || continue
  /bin/rm -rf -- "$event_dir"
done
