# Security Policy

## Supported version

The latest version on the `main` branch is supported.

## Reporting a vulnerability

Please do not publish security-sensitive details in a public issue. Use the repository owner's GitHub profile to make private contact, including a clear description and steps to reproduce the issue.

## Handling credentials

Never commit `~/.mac-alert/config`. It contains the Telegram bot token, chat ID, email address, and delivery settings. SMTP app passwords are stored only in the login Keychain. If a bot token is exposed, revoke it with BotFather and create a replacement token immediately.
