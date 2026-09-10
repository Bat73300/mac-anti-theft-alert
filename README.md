# Mac Anti-Theft Alert

**Get an instant Telegram and email alert whenever your locked Mac is plugged back into power.** This small macOS utility detects the battery-to-AC transition and reports the Mac name, time, Wi-Fi status, local and public IP addresses, an optional trusted-network label, and a webcam photo. It was tested while the Mac was locked in an already-open user session.

It delivers each alert through two independent channels:

- **Telegram:** a dedicated bot sends the alert text and webcam photo to a private chat.
- **Email:** Mail.app sends the same information and photo attachment to the configured email address.

If Telegram is unavailable, the alert is saved locally and retried automatically when the network returns. Mail.app hands delivery to its own outbox when the Mac is offline.

## What it does

- Watches the current power source once per minute through a user LaunchAgent.
- Detects a battery-to-AC transition.
- Runs a Shortcut, which has the macOS permissions to use the camera and Mail.app.
- Waits up to two minutes for the network, then collects network details and a photo with `imagesnap`.
- Sends the text and photo to Telegram and an email through Mail.app.
- Queues the Telegram payload securely under `~/.mac-alert/pending` if the Mac is offline.

The queue is local to the Mac. It is intended to preserve the alert, not to bypass macOS permissions or account security.

## Requirements

- This configuration was developed and tested only on **macOS 27**. Other macOS versions may require adjustments, particularly for Shortcuts, privacy permissions, and LaunchAgents.
- macOS with Shortcuts and Mail.app configured with a sending account.
- [Homebrew](https://brew.sh/) and `imagesnap`.
- A Telegram bot created through [@BotFather](https://t.me/BotFather).
- A private Telegram chat with that bot, after pressing **Start**.

### Install Homebrew and `imagesnap`

Homebrew is the package manager used here to install `imagesnap`, a small command-line utility that captures a still image from the built-in or connected webcam.

First, check whether Homebrew is already available:

```sh
brew --version
```

If the command is not found, install Homebrew with the installer published on the [official Homebrew website](https://brew.sh/):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the installer prompts. On some Macs, it will show one additional command to add `brew` to your shell path; run that command before continuing. Confirm the installation with `brew --version`.

Then install `imagesnap`:

```sh
brew install imagesnap
```

Confirm that macOS can find it:

```sh
imagesnap -h
```

Run one local camera test before enabling the automation:

```sh
imagesnap ~/Desktop/imagesnap-test.jpg
```

macOS may ask for camera access. Allow it for the app that starts the command, then check that `imagesnap-test.jpg` was created on the Desktop. You can delete this test image afterwards.

## Set up Telegram

1. Create a dedicated bot with BotFather and store its token safely.
2. Open the bot conversation, press **Start**, and send it a test message.
3. Retrieve your chat ID locally. After your configuration file exists, run:

   ```sh
   /bin/zsh -dfc '
   source "$HOME/.mac-alert/config"
   /usr/bin/curl -sS --max-time 20 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" > /tmp/mac-alert-updates.json
   /usr/bin/plutil -extract result.0.message.chat.id raw /tmp/mac-alert-updates.json
   '
   ```

Do not paste a Telegram token into issues, screenshots, chat messages, or a repository. Revoke and replace it immediately if it is exposed.

## Install

Clone or download this repository, then from its folder run:

```sh
chmod +x install.sh
./install.sh
```

This creates `~/.mac-alert` with private permissions and copies `config.example` to `~/.mac-alert/config` when the file does not already exist.

Edit the configuration:

```sh
nano ~/.mac-alert/config
```

Fill in only your own values:

```sh
TELEGRAM_BOT_TOKEN='your-bot-token'
TELEGRAM_CHAT_ID='your-chat-id'
EMAIL_TO='you@example.com'

# Optional: public IPs which should show as “At home”.
HOME_PUBLIC_IPS='203.0.113.10'
```

Save in Nano with `Ctrl+O`, press `Return`, then exit with `Ctrl+X`.

## Create the Shortcut

The LaunchAgent calls a Shortcut so that macOS can grant access to the camera and Mail.app.

1. Open **Shortcuts** and create a new shortcut named exactly **Mac Anti-Theft Alert**.
2. Add the **Run Shell Script** action.
3. Use `/bin/zsh` as the shell and enter:

   ```sh
   "$HOME/.mac-alert/mac-alert.sh"
   ```

4. In Shortcuts settings, enable **Allow Running Scripts** if macOS shows that option.
5. Run the shortcut once by hand. Approve the camera and Mail.app prompts when macOS asks.

Then enable the power watcher:

```sh
./install.sh --enable
```

## Test it

Run a local diagnostic without sending anything:

```sh
~/.mac-alert/mac-alert.sh --dry-run
```

Run the Shortcut manually to send a full test. Confirm that Telegram receives a text alert and a photo, and that Mail.app sends an email with the photo attached.

For a power test, unplug the Mac, wait for the next one-minute poll, and plug it back in. The watcher triggers only when it observes the transition from battery to AC. It deliberately does not alert immediately after installation or login.

Test the intended locked-screen case as well: lock the Mac, connect power, then verify the alert after signing back in. Results may vary while the Mac is in deep sleep because user processes and network access can be suspended.

## Limitations

- **After a restart:** this project uses a per-user LaunchAgent. It cannot send an alert before that user has signed in after a restart. The initial macOS login screen is not an active user session.
- **While asleep:** scripts do not run during sleep. If the Mac is connected to power while asleep, the transition can be detected only after the Mac wakes and the watcher runs again. Delivery then also depends on the network returning.
- **Locked screen:** it is designed for a Mac locked within an already-open user session. This is different from the first login screen shown immediately after restarting the Mac.
- **Deep sleep and power loss:** prolonged sleep, a completely drained battery, shutdown, or loss of network may prevent an immediate alert. Telegram alerts that are created while offline are kept in the local queue and retried after connectivity returns.

## Offline behaviour

If Telegram cannot be reached after two minutes, the script saves the text and, if available, photo in `~/.mac-alert/pending` using private permissions. The LaunchAgent retries queued Telegram items once per minute and deletes an item only after all of its parts have been sent.

Mail.app is asked to send each alert independently; its own outbox handles mail delivery while offline.

## Security and privacy

- Keep `~/.mac-alert/config` at mode `600`; it contains the bot token.
- Do not commit the completed config file. The repository contains only `config.example`.
- Webcam photos and queued data remain locally protected until sent.
- `HOME_PUBLIC_IPS` only labels known public IP addresses. This project does not call an external geolocation service.
- Treat Telegram bot access and Mail.app access as sensitive. Remove the LaunchAgent and revoke the bot token if the Mac is transferred to someone else.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No photo | Run the Shortcut manually and approve camera access for Shortcuts and `imagesnap`. |
| Telegram message arrives without a photo | Check `imagesnap` is installed and allowed to access the camera. |
| Wi-Fi shows “SSID unavailable” | macOS can hide the SSID from background processes. A local IP still indicates connectivity. |
| No automatic power alert | Ensure the Shortcut name matches exactly, then run `launchctl print gui/$(id -u)/com.example.mac-alert-power`. |
| Alert waits for network | Inspect `~/.mac-alert/pending`; it will retry automatically once Telegram is reachable. |

## License

Released under the [MIT License](LICENSE).
