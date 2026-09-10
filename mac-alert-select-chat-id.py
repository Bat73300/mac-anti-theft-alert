#!/usr/bin/python3
"""Return one private Telegram chat ID that matches an owner verification phrase."""

import json
import sys
from pathlib import Path


def fail() -> None:
    print(
        "mac-alert: Send one unique phrase to the bot, then run this helper with the same phrase.",
        file=sys.stderr,
    )
    raise SystemExit(1)


if len(sys.argv) != 3:
    raise SystemExit("Usage: mac-alert-select-chat-id.py RESPONSE_FILE UNIQUE_PHRASE")

try:
    payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, UnicodeDecodeError, json.JSONDecodeError):
    fail()

phrase = sys.argv[2]
matches = []
updates = payload.get("result", [])
if not isinstance(updates, list):
    fail()

for update in updates:
    if not isinstance(update, dict):
        continue
    message = update.get("message", {})
    if not isinstance(message, dict):
        continue
    chat = message.get("chat", {})
    sender = message.get("from", {})
    if not isinstance(chat, dict) or not isinstance(sender, dict):
        continue
    if (
        message.get("text") == phrase
        and chat.get("type") == "private"
        and chat.get("id") == sender.get("id")
    ):
        matches.append(chat["id"])

# A unique phrase and matching sender/chat IDs prevent using a bot identifier,
# a group, or an unrelated update in Telegram's retained update history.
if len(matches) != 1:
    fail()

print(matches[0])
