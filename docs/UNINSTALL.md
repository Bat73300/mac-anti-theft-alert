# Uninstall

Run this from the downloaded project folder:

```sh
zsh uninstall.sh --purge-keychain
```

Preview the exact project-controlled items first, without deleting anything:

```sh
zsh uninstall.sh --dry-run --purge-keychain
```

It stops and removes both project LaunchAgents, removes `~/.mac-alert`
(including the configuration, bot token, offline queue, photos, scripts, and
lock-state marker), and deletes the matching SMTP app password from the login
Keychain.

The project cannot safely erase data held by other applications or services.
To remove those manually:

1. Delete the **Mac Anti-Theft Alert** Shortcut in Shortcuts.
2. Revoke or delete the dedicated bot through [@BotFather](https://t.me/BotFather).
3. Delete alert messages and attachments from Telegram and the email mailbox.
4. Optionally remove the camera helper with `brew uninstall imagesnap` if you
   installed it only for this project.
5. Review **System Settings → Privacy & Security → Camera** and disable any
   remaining permission entries for Shortcuts or `imagesnap`.

macOS, Telegram, Gmail, Time Machine, and other backup or logging systems may
retain their own historical records. No project-level uninstaller can remove
those records reliably.
