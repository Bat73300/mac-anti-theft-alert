# Contributing

Thank you for improving Mac Anti-Theft Alert.

## Before opening an issue

1. Read the [setup guide](docs/SETUP.md) and [test matrix](docs/USAGE.md).
2. Run `zsh tests/verify.sh` from a downloaded copy of the repository.
3. Run `~/.mac-alert/mac-alert-doctor.sh` on the affected Mac.
4. Remove Telegram tokens, chat IDs, email addresses, public IP addresses,
   photos, and Keychain details from reports.

## Pull requests

- Keep changes focused and explain the user-visible result.
- Keep comments and documentation in English.
- Run `zsh tests/verify.sh` before submitting.
- Do not add real configuration files, alert photos, queue contents, or
  credentials to the repository.

## Security reports

Do not open a public issue for a suspected vulnerability. Follow
[SECURITY.md](SECURITY.md) instead.
