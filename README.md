# Mac Anti-Theft Alert

**Get a Telegram and email alert when a Mac is connected back to power, including while its already-open user session is locked.**

Mac Anti-Theft Alert is a small macOS utility for a specific signal: a change
from battery power to AC power. An alert can include the Mac name, time,
network details, an optional trusted-network label, and an optional webcam
photo. It sends through a dedicated Telegram bot and email, with direct SMTP
available when Mail.app is not configured.

![Power connection alert flow](assets/alert-flow.svg)

> [!IMPORTANT]
> This project sends an alert after a power connection is detected. It does
> not locate, lock, recover, or otherwise prevent theft of a Mac.

## Before you install

- Developed and tested only on **macOS 27**.
- Requires Shortcuts and a Telegram bot. Webcam photos additionally require
  [Homebrew](https://brew.sh/) and imagesnap.
- Uses a **per-user** macOS LaunchAgent. It starts after that user signs in;
  there is no app to open after a restart.
- Can send alert data and an optional photo to Telegram and your email
  provider. Read the [security review](docs/SECURITY-REVIEW.md) first.

## Choose a mode

| Mode | Behaviour |
| --- | --- |
| **Always** | Alerts while the signed-in session is open or locked. Useful for setup and testing. |
| **Locked only** | Alerts only at the lock screen of an already-open user session. |
| **Off** | Stops monitoring and queue retries until another mode is selected. |

In **Locked only** mode, lock and unlock the Mac once after installation, a
restart, or returning from Off. This safely initializes the lock monitor before
the first real test.

## Get started

1. Follow the [installation guide](docs/INSTALL.md).
2. Complete [Telegram, email, Shortcut, and mode setup](docs/SETUP.md).
3. Run the local [usage and test matrix](docs/USAGE.md) before relying on an
   automatic alert.
4. Keep the [uninstall guide](docs/UNINSTALL.md) available if the Mac changes
   owner or the project is no longer needed.

The read-only setup check is a useful first step after configuration:

~~~sh
~/.mac-alert/mac-alert-doctor.sh
~~~

It sends no alert, opens no camera, contacts no network, and does not access a
Keychain password.

## What happens after a restart?

The two LaunchAgents start automatically after the user signs in, then the
power watcher checks once per minute. In **Always** mode, wait for one poll
before testing. In **Locked only** mode, lock and unlock the session once after
every restart. The first macOS login screen is not an already-open user
session, so it cannot send an alert.

Check local monitoring status without sending an alert:

~~~sh
~/.mac-alert/mac-alert-power-watch.sh --status
~~~

## Limitations

The utility cannot guarantee an immediate alert during deep sleep, shutdown,
a drained battery, or a network outage. Telegram and direct SMTP alerts that
cannot be sent are kept in a private local queue and retried when the network
returns. See [Usage](docs/USAGE.md) for the full test matrix and
[Security review](docs/SECURITY-REVIEW.md) for the privacy model.

## Project resources

- [Installation](docs/INSTALL.md)
- [Setup](docs/SETUP.md)
- [Usage and testing](docs/USAGE.md)
- [Security review](docs/SECURITY-REVIEW.md)
- [Uninstall](docs/UNINSTALL.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Release checklist](docs/RELEASE.md)

Released under the [MIT License](LICENSE).
