# Usage and testing

## Manual checks

Run the read-only diagnostic first. It checks local setup and sends no alert,
opens no camera, contacts no network, and does not read a Keychain password:

```sh
~/.mac-alert/mac-alert-doctor.sh
```

The diagnostic exits with `0` when no local setup issue is found, and `1` when
it lists an item to fix. Its result does not prove that an external provider
will accept delivery; run the guided setup test after it succeeds:

```sh
~/.mac-alert/mac-alert-setup-test.sh
```

Then run this local capture test. It takes a photo and prints the data but
sends nothing:

```sh
~/.mac-alert/mac-alert.sh --dry-run
```

The guided test runs the Shortcut once and explains any expected macOS privacy
prompts. Confirm the text, timestamped photo attachment, Wi-Fi status,
local/public IP, and trusted-network label.

## Power transition test

1. Keep the Mac awake and unplug it.
2. Wait at least one watcher interval (60 seconds).
3. Connect power.
4. Wait for Telegram and email.

For **Locked only**, lock the already-open user session before step 3. The
monitor deliberately does not alert at installation, login, or on the first
poll; it needs to observe a battery-to-AC transition.

After a fresh installation, a restart, or re-enabling from Off, first perform
one lock/unlock cycle (`Control` + `Command` + `Q`, then sign back in). This
initializes the lock monitor before the power transition test.

## Test matrix

| Scenario | Expected result |
| --- | --- |
| Open session + Always | Telegram and email alert |
| Locked session + Always | Telegram and email alert |
| Open session + Locked only | No alert |
| Locked session + Locked only | Telegram and email alert |
| Off | No monitoring, alert, or queue retry; existing queued items stay local |
| No camera permission | Text alert, no photo |
| No network | Private local queue is created and retried later |
| SMTP unavailable | Email is queued and retried later |
| Restart, deep sleep, or first login screen | No immediate guarantee; see README limitations |

Inspect mode and screen state without sending an alert:

```sh
~/.mac-alert/mac-alert-power-watch.sh --status
```
