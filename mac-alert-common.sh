#!/bin/zsh
# Shared helpers. Every alert script imports this file. Its most important job
# is reading the private configuration as data, never as executable shell code.

set -u
set -o pipefail

# Values are collected in one pass so duplicate settings cannot silently win.
typeset -gA MAC_ALERT_CONFIG

trim_config_text() {
  REPLY="$1"
  REPLY="${REPLY#"${REPLY%%[![:space:]]*}"}"
  REPLY="${REPLY%"${REPLY##*[![:space:]]}"}"
}

parse_config() {
  local config_file="$1" line key value mode
  [[ -r "$config_file" ]] || { print -u2 -- "mac-alert: Configuration not found: $config_file"; return 1; }
  mode=$(/usr/bin/stat -f '%Lp' "$config_file" 2>/dev/null) || return 1
  [[ "$mode" == 600 || "$mode" == 400 ]] || { print -u2 -- "mac-alert: $config_file must have permission 600"; return 1; }
  MAC_ALERT_CONFIG=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    trim_config_text "$line"; line="$REPLY"
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || { print -u2 -- "mac-alert: Invalid configuration line"; return 1; }
    key="${line%%=*}"
    value="${line#*=}"
    trim_config_text "$key"; key="$REPLY"
    trim_config_text "$value"; value="$REPLY"
    case "$key" in
      TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID|EMAIL_TO|EMAIL_DELIVERY|SMTP_URL|SMTP_USER|SMTP_FROM|SMTP_KEYCHAIN_SERVICE|SHORTCUT_NAME|ALERT_MODE|HOME_PUBLIC_IPS|CAPTURE_PHOTO|LOOKUP_PUBLIC_IP|QUEUE_MAX_AGE_DAYS|QUEUE_MAX_ITEMS) ;;
      *) print -u2 -- "mac-alert: Unsupported configuration key: $key"; return 1 ;;
    esac
    [[ -z "${MAC_ALERT_CONFIG[$key]+present}" ]] || { print -u2 -- "mac-alert: Duplicate configuration key: $key"; return 1; }
    if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
      [[ "${value[1]}" == "${value[-1]}" && ${#value} -ge 2 ]] || { print -u2 -- "mac-alert: Unclosed quote in $key"; return 1; }
      # Quotes are syntax only; they never cause a second shell evaluation.
      value="${value[2,-2]}"
    fi
    [[ "$value" != *$'\r'* && "$value" != *$'\t'* ]] || { print -u2 -- "mac-alert: Invalid characters in $key"; return 1; }
    MAC_ALERT_CONFIG[$key]="$value"
  done < "$config_file"
}

load_config() {
  local config_file="$1"
  parse_config "$config_file" || return 1
  TELEGRAM_BOT_TOKEN="${MAC_ALERT_CONFIG[TELEGRAM_BOT_TOKEN]:-}"
  TELEGRAM_CHAT_ID="${MAC_ALERT_CONFIG[TELEGRAM_CHAT_ID]:-}"
  EMAIL_TO="${MAC_ALERT_CONFIG[EMAIL_TO]:-}"
  EMAIL_DELIVERY="${MAC_ALERT_CONFIG[EMAIL_DELIVERY]:-mail_app}"
  SMTP_URL="${MAC_ALERT_CONFIG[SMTP_URL]:-}"
  SMTP_USER="${MAC_ALERT_CONFIG[SMTP_USER]:-}"
  SMTP_FROM="${MAC_ALERT_CONFIG[SMTP_FROM]:-}"
  SMTP_KEYCHAIN_SERVICE="${MAC_ALERT_CONFIG[SMTP_KEYCHAIN_SERVICE]:-mac-alert.smtp}"
  SHORTCUT_NAME="${MAC_ALERT_CONFIG[SHORTCUT_NAME]:-Mac Anti-Theft Alert}"
  ALERT_MODE="${MAC_ALERT_CONFIG[ALERT_MODE]:-}"
  HOME_PUBLIC_IPS="${MAC_ALERT_CONFIG[HOME_PUBLIC_IPS]:-}"
  CAPTURE_PHOTO="${MAC_ALERT_CONFIG[CAPTURE_PHOTO]:-}"
  LOOKUP_PUBLIC_IP="${MAC_ALERT_CONFIG[LOOKUP_PUBLIC_IP]:-}"
  QUEUE_MAX_AGE_DAYS="${MAC_ALERT_CONFIG[QUEUE_MAX_AGE_DAYS]:-}"
  QUEUE_MAX_ITEMS="${MAC_ALERT_CONFIG[QUEUE_MAX_ITEMS]:-}"
  ALERT_MODE="${ALERT_MODE:-always}"
  CAPTURE_PHOTO="${CAPTURE_PHOTO:-true}"
  LOOKUP_PUBLIC_IP="${LOOKUP_PUBLIC_IP:-true}"
  QUEUE_MAX_AGE_DAYS="${QUEUE_MAX_AGE_DAYS:-7}"
  QUEUE_MAX_ITEMS="${QUEUE_MAX_ITEMS:-50}"
  [[ "$ALERT_MODE" == always || "$ALERT_MODE" == locked_only || "$ALERT_MODE" == off ]] || { print -u2 -- "mac-alert: ALERT_MODE must be always, locked_only, or off"; return 1; }
  [[ "$CAPTURE_PHOTO" == true || "$CAPTURE_PHOTO" == false ]] || { print -u2 -- "mac-alert: CAPTURE_PHOTO must be true or false"; return 1; }
  [[ "$LOOKUP_PUBLIC_IP" == true || "$LOOKUP_PUBLIC_IP" == false ]] || { print -u2 -- "mac-alert: LOOKUP_PUBLIC_IP must be true or false"; return 1; }
  [[ "$QUEUE_MAX_AGE_DAYS" == <-> && "$QUEUE_MAX_ITEMS" == <-> ]] || { print -u2 -- "mac-alert: Queue limits must be whole numbers"; return 1; }
  [[ "$TELEGRAM_BOT_TOKEN" != *[\"\\]* && "$TELEGRAM_CHAT_ID" != *[\"\\]* ]] || { print -u2 -- "mac-alert: Invalid Telegram credential characters"; return 1; }
  [[ "$EMAIL_DELIVERY" == mail_app || "$EMAIL_DELIVERY" == smtp ]] || { print -u2 -- "mac-alert: EMAIL_DELIVERY must be mail_app or smtp"; return 1; }
  if [[ "$EMAIL_DELIVERY" == smtp ]]; then
    [[ -n "$SMTP_URL" && -n "$SMTP_USER" && -n "$SMTP_FROM" && -n "$SMTP_KEYCHAIN_SERVICE" ]] || { print -u2 -- "mac-alert: SMTP settings are required"; return 1; }
    [[ "$SMTP_URL" == smtp://* || "$SMTP_URL" == smtps://* ]] || { print -u2 -- "mac-alert: SMTP_URL must start with smtp:// or smtps://"; return 1; }
    [[ "$SMTP_URL$SMTP_USER$SMTP_FROM$SMTP_KEYCHAIN_SERVICE" != *[\"\\]* ]] || { print -u2 -- "mac-alert: Invalid SMTP characters"; return 1; }
  fi
}

telegram_message() {
  local message_file="$1"
  {
    print -- 'silent'
    print -- 'fail'
    print -- 'connect-timeout = 5'
    print -- 'max-time = 30'
    curl_config_line url "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    curl_config_line data-urlencode "chat_id=${TELEGRAM_CHAT_ID}"
    curl_config_line data-urlencode "text@${message_file}"
  } | /usr/bin/curl --config - >/dev/null
}

telegram_photo() {
  local photo_file="$1"
  {
    print -- 'silent'
    print -- 'fail'
    print -- 'connect-timeout = 5'
    print -- 'max-time = 30'
    curl_config_line url "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto"
    curl_config_line form "chat_id=${TELEGRAM_CHAT_ID}"
    curl_config_line form "photo=@${photo_file}"
  } | /usr/bin/curl --config - >/dev/null
}

# Escape values before placing them in curl's quoted configuration syntax.
# This preserves Telegram fields without allowing them to become extra curl
# options. The bot token stays in curl's private standard-input configuration.
curl_config_line() {
  local option="$1"
  local encoded="$2"
  encoded="${encoded//\\/\\\\}"
  encoded="${encoded//\"/\\\"}"
  print -r -- "$option = \"$encoded\""
}

# macOS has no built-in `timeout` command. This lightweight Perl wrapper uses
# an alarm inherited through exec, avoiding a shell background-job race while
# giving Keychain and SMTP operations a hard deadline.
run_with_timeout() {
  local seconds="$1" result
  shift
  /usr/bin/perl -e '$seconds = shift @ARGV; alarm $seconds; exec @ARGV or die "exec failed: $!\n"' "$seconds" "$@"
  result=$?
  # SIGALRM conventionally becomes 128 + 14 when no shell has translated it.
  if (( result == 142 )); then
    return 124
  fi
  return "$result"
}

# Direct SMTP sender. The Python helper reads the password from Keychain inside
# its own process; it is never written into the configuration or command line.
smtp_send() {
  [[ -x /usr/bin/python3 ]] || {
    print -u2 -- "mac-alert: Python 3 is required for direct SMTP delivery"
    return 1
  }
  # This includes the one-time Keychain consent dialog (up to 60 seconds),
  # plus the bounded TLS/SMTP connection and delivery.
  run_with_timeout 90 /usr/bin/python3 "$HOME/.mac-alert/mac-alert-send-smtp.py" \
    "$SMTP_URL" "$SMTP_USER" "$SMTP_FROM" "$EMAIL_TO" "$SMTP_KEYCHAIN_SERVICE" \
    "$3" "$1" "${2:-}"
}

prune_pending_alerts() {
  local pending_dir="$1" age_days="$QUEUE_MAX_AGE_DAYS" max_items="$QUEUE_MAX_ITEMS"
  [[ "$age_days" == <-> ]] || age_days=7
  [[ "$max_items" == <-> ]] || max_items=50
  /usr/bin/find "$pending_dir" -mindepth 1 -maxdepth 1 -type d -mtime +"$age_days" -exec /bin/rm -rf -- {} + 2>/dev/null || true
  local -a events
  events=("$pending_dir"/*(N/))
  while (( ${#events} > max_items )); do
    /bin/rm -rf -- "$events[1]"
    shift events
  done
}
