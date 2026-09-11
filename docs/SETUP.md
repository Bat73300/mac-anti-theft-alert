# Setup

Complete these steps after [installation](INSTALL.md).

## 1. Create and configure the Telegram bot

1. Open [@BotFather](https://t.me/BotFather) in Telegram and send `/newbot`.
2. Choose a name and unique username, then save the token outside screenshots,
   chat history, and source code.
3. Open the new bot, choose **Start**, and send one unique phrase, for example
   `mac-alert-verify-blue-sparrow`. Do not reuse this phrase for another bot
   or group.
4. Edit the local configuration:

   ```sh
   nano ~/.mac-alert/config
   ```

5. Add your token, save the file, then retrieve the chat ID locally using the
   exact same phrase:

   ```sh
   ~/.mac-alert/mac-alert-get-chat-id.sh 'mac-alert-verify-blue-sparrow'
   ```

   This prints the ID of the **private conversation between you and the bot**.
   Put that number in `TELEGRAM_CHAT_ID`.

   > Do **not** use the numerical bot ID returned by Telegram’s `getMe` API or
   > shown by BotFather. A bot cannot send a message to itself; that mistake
   > produces `Forbidden: the bot can't send messages to the bot`.

6. Add that private chat ID and an email address to `~/.mac-alert/config`. Save with
   `Ctrl+O`, `Return`, then `Ctrl+X`.

Never publish the token. If it is exposed, revoke it through BotFather and
replace it in the local configuration.

## 2. Choose email delivery

The default is `EMAIL_DELIVERY='mail_app'`, which uses the account already set
up in Mail.app. Run the Shortcut once manually so macOS can request approval.

For email without Mail.app, set `EMAIL_DELIVERY='smtp'`, add the SMTP settings
shown in `config.example`, and store the provider app password in the login
Keychain. For a personal Gmail account, first enable two-step verification and
create an **App password** in the Google Account security settings. Use that
16-character app password, never the normal Google account password.

Direct SMTP requires Python 3. If it is not already installed, run:

```sh
brew install python
```

Store it in **Keychain Access** under the **login** keychain:

1. Choose **File → New Password Item**.
2. Set **Keychain Item Name** to `mac-alert.smtp`.
3. Set **Account Name** to the same Gmail address used in `EMAIL_TO`.
4. Paste the Google app password in **Password** and save.

Then run the helper for personal Gmail:

```sh
~/.mac-alert/mac-alert-configure-gmail-smtp.sh
```

It configures direct TLS delivery through Gmail and expects the Keychain item
described above. The password is never placed in the configuration file.

At the first direct-SMTP test, macOS asks for the session password to allow
the `security` tool to read this one Keychain item. Choose **Always Allow**.
The initial prompt can take up to one minute; later alerts run without it.

## 3. Create the Shortcut

1. Open **Shortcuts** and create **Mac Anti-Theft Alert**.
2. Add **Run Shell Script**, choose `/bin/zsh`, and use:

   ```sh
   "$HOME/.mac-alert/mac-alert.sh"
   ```

3. Do not test it manually yet: use the guided test in the next step so it
   explains every expected macOS permission prompt.
4. If you chose a different Shortcut name, set the same value in
   `SHORTCUT_NAME` within `~/.mac-alert/config`.

## 4. Run the voluntary setup test

This test sends one real alert to the configured Telegram chat and email
address. It is the safe moment to approve macOS prompts because it runs the
same Shortcut and alert worker used during normal operation:

```sh
~/.mac-alert/mac-alert-setup-test.sh
```

The helper asks for confirmation before sending anything. Depending on the
configuration, macOS may request:

- Camera access for Shortcuts or `imagesnap` when photos are enabled.
- Permission to access the one SMTP app password in the login Keychain. Choose
  **Always Allow** only after confirming that the item is `mac-alert.smtp`.
- Permission for Shortcuts to control Mail.app when `mail_app` delivery is
  selected.

Confirm that both Telegram and email arrived, including the photo when it is
enabled. If a prompt is denied, correct it in **System Settings → Privacy &
Security**, then run the test again.

## 5. Select the alert mode and enable monitoring

```sh
~/.mac-alert/mac-alert-mode.sh
zsh install.sh --enable
```

**Always** alerts in an open or locked session. **Locked only** alerts only at
the macOS lock screen of an already-open session. **Off** unloads both project
monitors and prevents alerts and queue retries until another mode is selected.

### Initialize Locked only

After installation, after selecting **Locked only** from Off, or after the
Mac restarts, the lock monitor starts in an `unknown` state and deliberately
does not alert. Lock the screen once with `Control` + `Command` + `Q`, then
sign back in once. This records the current unlocked state and prepares the
next real locked-screen power test.

### After restarting the Mac

No graphical application needs to be opened. After the user signs in, macOS
loads the project LaunchAgents automatically and the power watcher checks once
per minute.

- **Always:** ready after sign-in; wait one minute before a power-transition
  test.
- **Locked only:** complete the lock/unlock initialization above after every
  restart.
- **Off:** remains inactive until Always or Locked only is selected again.

Check the current local mode and screen state without sending an alert:

```sh
~/.mac-alert/mac-alert-power-watch.sh --status
```
