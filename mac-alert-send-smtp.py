#!/usr/bin/python3
"""Send one alert through SMTP without exposing the Keychain password."""

import argparse
from email.message import EmailMessage
from pathlib import Path
import smtplib
import ssl
import subprocess
import sys
from urllib.parse import urlparse


def fail(message: str) -> None:
    print(f"mac-alert: {message}", file=sys.stderr)
    raise SystemExit(1)


parser = argparse.ArgumentParser(add_help=False)
parser.add_argument("smtp_url")
parser.add_argument("smtp_user")
parser.add_argument("smtp_from")
parser.add_argument("email_to")
parser.add_argument("keychain_service")
parser.add_argument("subject")
parser.add_argument("message_file")
parser.add_argument("photo_file")
args = parser.parse_args()

parsed = urlparse(args.smtp_url)
if (
    parsed.scheme not in {"smtp", "smtps"}
    or not parsed.hostname
    or parsed.username
    or parsed.password
    or parsed.path not in {"", "/"}
    or parsed.params
    or parsed.query
    or parsed.fragment
):
    fail("Invalid SMTP server configuration")

try:
    port = parsed.port or (465 if parsed.scheme == "smtps" else 587)
except ValueError:
    fail("Invalid SMTP server port")

# The app password is deliberately fetched inside this short-lived process.
# It is therefore absent from shell arguments, environment variables, config,
# logs, and the generated message.
try:
    password = subprocess.check_output(
        ["/usr/bin/security", "find-generic-password", "-a", args.smtp_user,
         "-s", args.keychain_service, "-w"],
        stderr=subprocess.DEVNULL,
        text=True,
        # The first Keychain access can show a macOS consent dialog. Allow a
        # full minute for the user to approve it; later unattended reads are
        # immediate once “Always Allow” has been chosen.
        timeout=60,
    ).rstrip("\n")
except (subprocess.SubprocessError, OSError):
    fail("SMTP password could not be read from Keychain")

message = EmailMessage()
message["From"] = args.smtp_from
message["To"] = args.email_to
message["Subject"] = args.subject
message.set_content(Path(args.message_file).read_text(encoding="utf-8"))

photo = Path(args.photo_file)
if photo.is_file() and photo.stat().st_size > 0:
    # EmailMessage owns base64/MIME encoding, avoiding hand-built attachment
    # boundaries and preserving the camera file exactly as captured.
    message.add_attachment(
        photo.read_bytes(), maintype="image", subtype="jpeg", filename=photo.name
    )

context = ssl.create_default_context()
try:
    # `smtps` is direct TLS; `smtp` explicitly upgrades through STARTTLS.
    # Both routes use the system certificate store and a bounded socket timeout.
    if parsed.scheme == "smtps":
        client = smtplib.SMTP_SSL(parsed.hostname, port, timeout=20, context=context)
    else:
        client = smtplib.SMTP(parsed.hostname, port, timeout=20)
        client.ehlo()
        client.starttls(context=context)
        client.ehlo()
    with client:
        client.login(args.smtp_user, password)
        client.send_message(message)
except (OSError, smtplib.SMTPException):
    fail("SMTP transport was refused or timed out")
