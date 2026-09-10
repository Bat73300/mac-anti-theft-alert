#!/bin/zsh
# Optional Gmail setup helper. It enables direct Gmail SMTP using the current
# EMAIL_TO address and the app password already stored as mac-alert.smtp in the
# login Keychain. It never reads or prints that password.
set -eu

alert_dir="$HOME/.mac-alert"
config_file="$alert_dir/config"
temporary_file="$(/usr/bin/mktemp "$alert_dir/config.XXXXXX")"
source "$alert_dir/mac-alert-common.sh"
trap '/bin/rm -f -- "$temporary_file"' EXIT

load_config "$config_file"
[[ "$EMAIL_TO" == *@gmail.com || "$EMAIL_TO" == *@googlemail.com ]] || {
  print -u2 -- "mac-alert: EMAIL_TO must be a personal Gmail address for this helper"
  exit 1
}

# Replace a previous SMTP setup without changing Telegram, privacy, or mode.
/usr/bin/sed -E '/^(EMAIL_DELIVERY|SMTP_URL|SMTP_USER|SMTP_FROM|SMTP_KEYCHAIN_SERVICE)=/d' "$config_file" > "$temporary_file"
{
  print -- ''
  print -- '# Direct Gmail SMTP: password is stored in the login Keychain.'
  print -- "EMAIL_DELIVERY='smtp'"
  # Direct TLS avoids STARTTLS negotiation stalls observed on some networks.
  print -- "SMTP_URL='smtps://smtp.gmail.com:465'"
  print -- "SMTP_USER='$EMAIL_TO'"
  print -- "SMTP_FROM='$EMAIL_TO'"
  print -- "SMTP_KEYCHAIN_SERVICE='mac-alert.smtp'"
} >> "$temporary_file"
/bin/chmod 600 "$temporary_file"
/bin/mv -f "$temporary_file" "$config_file"
print -- 'mac-alert: Direct Gmail SMTP configured.'
