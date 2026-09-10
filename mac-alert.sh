#!/bin/zsh
# Alert when this Mac comes online. Secrets stay only in ~/.mac-alert/config.
set -u
set -o pipefail

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
pending_dir="$alert_dir/pending"
photo_file="$alert_dir/mac-alert-$(date +%Y%m%d-%H%M%S).jpg"
dry_run=false

if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
fi

log() { print -r -- "mac-alert: $*" >&2; }
cleanup() { rm -f "$photo_file"; }
trap cleanup EXIT

queue_alert() {
  local event_dir
  event_dir="$pending_dir/$(date +%Y%m%d-%H%M%S)-$$"
  (umask 077; /bin/mkdir -p "$event_dir") || return 1
  print -r -- "$message" > "$event_dir/message.txt"
  /bin/chmod 600 "$event_dir/message.txt"
  if [[ -f "$photo_file" ]]; then
    /bin/cp -p "$photo_file" "$event_dir/photo.jpg"
    /bin/chmod 600 "$event_dir/photo.jpg"
  fi
}

if [[ ! -r "$config_file" && "$dry_run" != true ]]; then
  log "Configuration not found: $config_file"
  exit 1
fi

if [[ -r "$config_file" ]]; then
  source "$config_file"
fi
if [[ "$dry_run" != true && ( -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" || -z "${EMAIL_TO:-}" ) ]]; then
  log "Set TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, and EMAIL_TO in $config_file"
  exit 1
fi

# Let Wi-Fi and DNS settle after wake or power connection (max. two minutes).
network_available=false
for _ in {1..24}; do
  if /usr/sbin/scutil -r api.telegram.org | /usr/bin/grep -q Reachable; then
    network_available=true
    break
  fi
  /bin/sleep 5
done

mac_name=$(/usr/sbin/scutil --get ComputerName 2>/dev/null || /bin/hostname)
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
public_ip=$(/usr/bin/curl --connect-timeout 5 --max-time 10 --silent --show-error https://api.ipify.org 2>/dev/null || true)
[[ -n "$public_ip" ]] || public_ip="Unavailable"

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

if (( $+commands[imagesnap] )); then
  imagesnap -w 2 "$photo_file" >/dev/null 2>&1 || log "Webcam photo unavailable"
else
  log "imagesnap was not found: sending without a photo"
fi

if [[ "$dry_run" == true ]]; then
  print -r -- "$message"
  [[ -f "$photo_file" ]] && log "Photo captured (local test)"
  exit 0
fi

if [[ "$network_available" == true ]]; then
  # Never print the URL: it embeds the bot token.
  /usr/bin/curl --fail --silent --show-error --max-time 20 \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${message}" \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" >/dev/null \
    || log "Could not send the Telegram message"

  if [[ -f "$photo_file" ]]; then
    /usr/bin/curl --fail --silent --show-error --max-time 30 \
      -F "chat_id=${TELEGRAM_CHAT_ID}" \
      -F "caption=${message}" \
      -F "photo=@${photo_file}" \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" >/dev/null \
      || log "Could not send the Telegram photo"
  fi
else
  queue_alert && log "Telegram alert queued until the network returns"
fi

# Mail.app can misread UTF-8 emitted by a shell-launched AppleScript. Use a
# small ASCII-only variant for Mail while Telegram keeps the original text.
mail_body="$message"
mail_body=${mail_body//é/e}
mail_body=${mail_body//è/e}
mail_body=${mail_body//ê/e}
mail_body=${mail_body//à/a}
mail_body=${mail_body//À/A}
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
