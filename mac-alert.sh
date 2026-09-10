#!/bin/zsh
# Main alert worker. Shortcuts runs it to collect permitted camera/network data,
# send Telegram and the selected email channel, and queue failed delivery.
set -u
set -o pipefail

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
pending_dir="$alert_dir/pending"
photo_file="$alert_dir/mac-alert-$(date +%Y%m%d-%H%M%S).jpg"
message_file=""
dry_run=false

source "$alert_dir/mac-alert-common.sh"

if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
fi

log() { print -r -- "mac-alert: $*" >&2; }
cleanup() { rm -f -- "$photo_file" "$message_file"; }
trap cleanup EXIT

queue_alert() {
  # Store only the delivery parts that still need retrying. This lets a later
  # retry avoid sending a duplicate Telegram text or SMTP email.
  local event_dir
  prune_pending_alerts "$pending_dir"
  event_dir="$pending_dir/$(date +%Y%m%d-%H%M%S)-$$"
  (umask 077; /bin/mkdir -p "$event_dir") || return 1
  print -r -- "$message" > "$event_dir/message.txt"
  /bin/chmod 600 "$event_dir/message.txt"
  if [[ -f "$photo_file" ]]; then
    /bin/cp -p "$photo_file" "$event_dir/photo.jpg"
    /bin/chmod 600 "$event_dir/photo.jpg"
  fi
  if [[ "$telegram_text_sent" == true ]]; then
    : > "$event_dir/message.sent"
    /bin/chmod 600 "$event_dir/message.sent"
  fi
  if [[ "$telegram_photo_sent" == true ]]; then
    : > "$event_dir/photo.sent"
    /bin/chmod 600 "$event_dir/photo.sent"
  fi
  if [[ "$smtp_mail_sent" == true ]]; then
    : > "$event_dir/mail.sent"
    /bin/chmod 600 "$event_dir/mail.sent"
  fi
}

if [[ ! -r "$config_file" && "$dry_run" != true ]]; then
  log "Configuration not found: $config_file"
  exit 1
fi

if [[ -r "$config_file" ]]; then
  load_config "$config_file" || exit 1
fi
if [[ "$dry_run" != true && ( -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" || -z "${EMAIL_TO:-}" ) ]]; then
  log "Set TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, and EMAIL_TO in $config_file"
  exit 1
fi

# Let Wi-Fi and DNS settle after wake or power connection.  A bounded HTTPS
# probe is used instead of `scutil -r`: on some networks the latter can wait
# indefinitely while resolving a route.  After 30 seconds delivery is simply
# queued and the Shortcut is allowed to finish.
network_available=false
for _ in {1..6}; do
  if /usr/bin/curl --silent --show-error --output /dev/null \
    --connect-timeout 3 --max-time 5 https://api.telegram.org; then
    network_available=true
    break
  fi
  /bin/sleep 5
done

mac_name=$(/usr/sbin/scutil --get ComputerName 2>/dev/null || /bin/hostname)
# The Mac name becomes part of an email subject. Strip line breaks so a custom
# computer name can never create an additional mail header.
mac_name=${mac_name//$'\r'/ }
mac_name=${mac_name//$'\n'/ }
timestamp=$(/bin/date '+%Y-%m-%d %H:%M:%S %Z')
wifi_device=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '/Wi-Fi|AirPort/{getline; print $2; exit}')
ssid="Unavailable"
local_ip="Unavailable"
if [[ -n "$wifi_device" ]]; then
  ssid=$(/usr/sbin/networksetup -getairportnetwork "$wifi_device" 2>/dev/null | /usr/bin/sed 's/^Current Wi-Fi Network: //' || true)
  local_ip=$(/usr/sbin/ipconfig getifaddr "$wifi_device" 2>/dev/null || true)
  [[ -n "$local_ip" ]] || local_ip="Unavailable"
  if [[ -z "$ssid" || "$ssid" == *"not associated"* ]]; then
    if [[ "$local_ip" == "Unavailable" ]]; then
      ssid="SSID unavailable"
    else
      ssid="Connected (SSID unavailable)"
    fi
  fi
fi
public_ip="Not collected"
if [[ "$LOOKUP_PUBLIC_IP" == true ]]; then
  public_ip=$(/usr/bin/curl --connect-timeout 5 --max-time 10 --silent --show-error https://api.ipify.org 2>/dev/null || true)
  [[ -n "$public_ip" ]] || public_ip="Unavailable"
fi

# Comma-separated public IP addresses that identify trusted places, beginning
# with home. Values stay in the local config file.
network_location="Unknown network"
if [[ -n "${HOME_PUBLIC_IPS:-}" && "$public_ip" != "Unavailable" ]]; then
  for known_ip in ${(s:,:)HOME_PUBLIC_IPS}; do
    known_ip="${known_ip//[[:space:]]/}"
    if [[ "$public_ip" == "$known_ip" ]]; then
      network_location="At home"
      break
    fi
  done
  [[ "$network_location" == "Unknown network" ]] && network_location="Away from known networks"
fi

message=$'Mac Alert\n\n'
message+="Mac: ${mac_name}"$'\n'
message+="Time: ${timestamp}"$'\n'
message+="Wi-Fi: ${ssid}"$'\n'
message+="Local IP: ${local_ip}"$'\n'
message+="Public IP: ${public_ip}"$'\n'
message+="Network location: ${network_location}"

if [[ "$CAPTURE_PHOTO" == true ]] && (( $+commands[imagesnap] )); then
  # Camera access occasionally stalls when macOS is displaying a permission
  # prompt.  Do not let that prevent the text alert: stop the helper after
  # 15 seconds and continue without a photo.
  imagesnap -w 2 "$photo_file" >/dev/null 2>&1 &
  imagesnap_pid=$!
  for _ in {1..15}; do
    kill -0 "$imagesnap_pid" 2>/dev/null || break
    /bin/sleep 1
  done
  if kill -0 "$imagesnap_pid" 2>/dev/null; then
    /bin/kill "$imagesnap_pid" 2>/dev/null || true
    wait "$imagesnap_pid" 2>/dev/null || true
    /bin/rm -f -- "$photo_file"
    log "Webcam photo timed out: sending without a photo"
  else
    wait "$imagesnap_pid" 2>/dev/null || log "Webcam photo unavailable"
  fi
else
  log "imagesnap was not found: sending without a photo"
fi

# imagesnap may use the caller's default umask. Restrict the short-lived local
# original as well as the queued copy before it is attached or sent.
[[ -f "$photo_file" ]] && /bin/chmod 600 "$photo_file"

if [[ "$dry_run" == true ]]; then
  print -r -- "$message"
  [[ -f "$photo_file" ]] && log "Photo captured (local test)"
  exit 0
fi

# A private message file gives Telegram and SMTP a shared, injection-safe body.
message_file=$(mktemp "$alert_dir/.alert-message.XXXXXX")
/bin/chmod 600 "$message_file"
print -r -- "$message" > "$message_file"
telegram_text_sent=false
telegram_photo_sent=false
smtp_mail_sent=false

if [[ "$network_available" == true ]]; then
  if telegram_message "$message_file"; then
    telegram_text_sent=true
  else
    log "Could not send the Telegram message"
  fi

  if [[ -f "$photo_file" ]]; then
    if telegram_photo "$photo_file"; then
      telegram_photo_sent=true
    else
      log "Could not send the Telegram photo"
    fi
  fi
fi

if [[ "$EMAIL_DELIVERY" == smtp ]]; then
  if smtp_send "$message_file" "$photo_file" "Mac Alert - ${mac_name}"; then
    smtp_mail_sent=true
  else
    log "Could not send the SMTP email"
  fi
fi

# Telegram and direct SMTP share the durable local retry queue. Mail.app keeps
# its own Outbox, so it is not duplicated here.
if [[ "$telegram_text_sent" != true || ( -f "$photo_file" && "$telegram_photo_sent" != true ) || ( "$EMAIL_DELIVERY" == smtp && "$smtp_mail_sent" != true ) ]]; then
  queue_alert && log "Alert delivery queued until the network returns"
fi

# Mail.app can misread UTF-8 emitted by a shell-launched AppleScript. Use a
# small ASCII-only variant for Mail while Telegram keeps the original text.
mail_body="$message"
mail_body=${mail_body//é/e}
mail_body=${mail_body//è/e}
mail_body=${mail_body//ê/e}
mail_body=${mail_body//à/a}
mail_body=${mail_body//À/A}
if [[ "$EMAIL_DELIVERY" == mail_app ]]; then
export MAC_ALERT_TO="$EMAIL_TO" MAC_ALERT_SUBJECT="Mac Alert - ${mac_name}" MAC_ALERT_BODY="$mail_body" MAC_ALERT_PHOTO="$photo_file"
/usr/bin/osascript <<'APPLESCRIPT' >/dev/null 2>&1 || log "Could not prepare the Mail message"
on run
  set recipientAddress to system attribute "MAC_ALERT_TO"
  set subjectText to system attribute "MAC_ALERT_SUBJECT"
  set bodyText to system attribute "MAC_ALERT_BODY"
  set photoPath to system attribute "MAC_ALERT_PHOTO"
  tell application "Mail"
    set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText & return & return, visible:false}
    tell newMessage
      make new to recipient at end of to recipients with properties {address:recipientAddress}
      if photoPath is not "" then
        try
          make new attachment with properties {file name:POSIX file photoPath} at after the last paragraph
        end try
      end if
      send
    end tell
  end tell
end run
APPLESCRIPT
fi
