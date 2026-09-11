#!/bin/zsh
# Explicit first-run delivery test. It deliberately runs the user's Shortcut
# once, so macOS can request the camera, Keychain, Mail automation, or
# Shortcuts permissions in the same context used by a real alert. Nothing is
# sent automatically by install.sh or doctor; this helper requires a clear yes.
set -eu

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
source "$alert_dir/mac-alert-common.sh"

load_config "$config_file"
[[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" && -n "$EMAIL_TO" ]] || {
  print -u2 -- 'mac-alert: Complete Telegram and email settings in ~/.mac-alert/config first.'
  exit 1
}
if [[ "$EMAIL_DELIVERY" == smtp ]]; then
  require_python3 || exit 1
fi
if ! /usr/bin/shortcuts list 2>/dev/null | /usr/bin/grep -Fxq -- "$SHORTCUT_NAME"; then
  print -u2 -- "mac-alert: Shortcut was not found: $SHORTCUT_NAME"
  exit 1
fi

print -- 'This will send one real test alert to your configured Telegram chat and email address.'
if [[ "$CAPTURE_PHOTO" == true ]]; then
  print -- 'macOS may ask Shortcuts or imagesnap for camera access.'
fi
if [[ "$EMAIL_DELIVERY" == smtp ]]; then
  print -- 'macOS may ask to allow Keychain access for the SMTP app password.'
else
  print -- 'macOS may ask Shortcuts to control Mail.app.'
fi
print -n -- 'Continue? [y/N] '
IFS= read -r answer
[[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || {
  print -- 'mac-alert: Setup test cancelled. No alert was sent.'
  exit 0
}

/usr/bin/shortcuts run "$SHORTCUT_NAME"
print -- 'mac-alert: Setup test finished. Confirm the Telegram and email alerts before enabling monitoring.'
