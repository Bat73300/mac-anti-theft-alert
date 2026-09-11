#!/bin/zsh
# Offline verification for a downloaded copy of the project. It never contacts
# Telegram, an SMTP provider, the webcam, or a real configuration file.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mac-alert-tests.XXXXXX")
trap '/bin/rm -rf -- "$work_dir"' EXIT

for file in "$root"/*.sh; do
  /bin/zsh -n "$file"
done
PYTHONPYCACHEPREFIX="$work_dir/python-cache" /usr/bin/python3 -m py_compile \
  "$root/mac-alert-send-smtp.py" "$root/mac-alert-select-chat-id.py"
/usr/bin/clang -fobjc-arc -framework Foundation -fsyntax-only "$root/mac-alert-lock-state-monitor.m"
for file in "$root"/*.plist; do
  /usr/bin/plutil -lint "$file" >/dev/null
done

# The parser accepts documented data and does not execute configuration values.
config="$work_dir/config"
cat > "$config" <<'CONFIG'
TELEGRAM_BOT_TOKEN='example-token'
TELEGRAM_CHAT_ID='12345'
EMAIL_TO='user@example.com'
SHORTCUT_NAME='Mac Anti-Theft Alert'
CAPTURE_PHOTO='false'
LOOKUP_PUBLIC_IP='false'
CONFIG
/bin/chmod 600 "$config"
source "$root/mac-alert-common.sh"
load_config "$config"
[[ "$CAPTURE_PHOTO" == false && "$SHORTCUT_NAME" == 'Mac Anti-Theft Alert' ]]

# A shell-looking configuration value remains inert data rather than code.
inert="$work_dir/inert"
cat > "$config" <<CONFIG
TELEGRAM_BOT_TOKEN='example-token'
TELEGRAM_CHAT_ID='12345'
EMAIL_TO='user@example.com'
SHORTCUT_NAME='\$(touch "$inert")'
CONFIG
/bin/chmod 600 "$config"
load_config "$config"
[[ "$SHORTCUT_NAME" == *'touch '* && ! -e "$inert" ]]

# The explicit off mode is a supported configuration value, not an error.
/usr/bin/sed -i '' "s/^SHORTCUT_NAME=.*/ALERT_MODE='off'/" "$config"
load_config "$config"
[[ "$ALERT_MODE" == off ]]

# Chat-ID selection accepts exactly one owner message in a private chat. This
# checks the parser without accessing a real Telegram account.
chat_updates="$work_dir/telegram-updates.json"
cat > "$chat_updates" <<'JSON'
{"ok":true,"result":[{"message":{"text":"blue-sparrow","chat":{"type":"private","id":24680},"from":{"id":24680}}}]}
JSON
selected_chat=$(/usr/bin/python3 "$root/mac-alert-select-chat-id.py" "$chat_updates" blue-sparrow)
[[ "$selected_chat" == 24680 ]]
cat > "$chat_updates" <<'JSON'
{"ok":true,"result":[{"message":{"text":"blue-sparrow","chat":{"type":"group","id":24680},"from":{"id":24680}}}]}
JSON
if /usr/bin/python3 "$root/mac-alert-select-chat-id.py" "$chat_updates" blue-sparrow >/dev/null 2>&1; then
  print -u2 -- 'Unexpected group chat accepted by chat-ID selector.'
  exit 1
fi

# Duplicate settings and credential-bearing SMTP URLs are rejected before any
# network request or Keychain access can be attempted.
cat > "$config" <<'CONFIG'
TELEGRAM_BOT_TOKEN='first'
TELEGRAM_BOT_TOKEN='second'
CONFIG
/bin/chmod 600 "$config"
if load_config "$config" >/dev/null 2>&1; then
  print -u2 -- 'Unexpected duplicate configuration key accepted.'
  exit 1
fi
if /usr/bin/python3 "$root/mac-alert-send-smtp.py" \
  'smtps://user:password@smtp.example.com:465' user@example.com \
  user@example.com user@example.com mac-alert.smtp subject "$config" '' >/dev/null 2>&1; then
  print -u2 -- 'Unexpected credential-bearing SMTP URL accepted.'
  exit 1
fi

if /usr/bin/grep -Eq 'source[[:space:]].*(/config|\$config)' "$root"/*.sh; then
  print -u2 -- 'Unexpected executable config load found.'
  exit 1
fi
# The diagnostic must remain read-only: it should never invoke an alert worker
# or access a Keychain password while it checks local prerequisites.
if /usr/bin/grep -Eq 'mac-alert\.sh|find-generic-password.*-w|telegram_message|smtp_send' "$root/mac-alert-doctor.sh"; then
  print -u2 -- 'Doctor must not send alerts or read Keychain passwords.'
  exit 1
fi
print -- 'mac-alert: offline verification passed.'
