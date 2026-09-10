# Usage and testing

## Manual checks

Run this first; it takes a local photo and prints the data but sends nothing:

```sh
~/.mac-alert/mac-alert.sh --dry-run
```

Run the Shortcut manually to test Telegram and the selected email channel.
Confirm the text, timestamped photo attachment, Wi-Fi status, local/public IP,
and trusted-network label.

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
