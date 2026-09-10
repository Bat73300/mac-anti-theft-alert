# Installation

This guide installs the project files only. Setup of Telegram, email delivery,
permissions, and the power watcher follows in [SETUP.md](SETUP.md).

## 1. Download the project

Clone the repository or download its ZIP archive, open Terminal in the project
folder, then run:

```sh
zsh install.sh
```

The installer creates `~/.mac-alert` with permissions restricted to the
current user, copies the scripts, compiles the lock-state monitor, and creates
the two per-user LaunchAgent plist files. It does **not** start monitoring yet.

## Where files are installed

The downloaded repository remains wherever the user cloned or unzipped it. It
is only the source used for installation, updates, verification, and removal.

The active per-user installation is kept outside `/Applications`:

| Location | Contents | Why it is there |
| --- | --- | --- |
| `~/.mac-alert` | Private configuration, scripts, queue, photos, and lock state | Restricted to the signed-in user; it can contain a Telegram token. |
| `~/Library/LaunchAgents` | Two per-user macOS automation definitions | They run only in that user’s already-open session, including at its lock screen. |

This is the normal macOS layout for a per-user script and LaunchAgent. It
avoids mixing private credentials with a graphical app in `/Applications` and
does not affect other user accounts on the same Mac.

## 2. Install the optional camera helper

Install [Homebrew](https://brew.sh/) if needed, then:

```sh
brew install imagesnap
imagesnap -h
```

`imagesnap` takes the optional webcam picture. The alert still installs and
sends text if it is not present, if a capture fails, or if permission has not
been granted.

Direct SMTP delivery also requires Python 3. The project checks for
`/usr/bin/python3` only when SMTP delivery is selected; Mail.app delivery does
not need it.

## 3. Verify the downloaded files

Run the offline check before adding any credentials:

```sh
zsh tests/verify.sh
```

It checks shell syntax, Python syntax, launch-agent plist files, the
lock-state monitor compilation, and safe parsing of a sample configuration.
It never opens the camera or contacts the internet.

After completing setup, use the read-only diagnostic before the first alert:

```sh
~/.mac-alert/mac-alert-doctor.sh
```

It checks configuration and file permissions, the Shortcut, the optional
camera helper, and the two LaunchAgents. It does not send an alert, open the
camera, contact the network, or read a Keychain password.
