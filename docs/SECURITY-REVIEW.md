# Security review

Reviewed on 2026-09-10 for version 1.1.0. This is a
source and configuration review, not a formal penetration test or a guarantee
against a compromised macOS account.

## Assets and trust boundaries

| Asset | Where it lives | Protection |
| --- | --- | --- |
| Telegram token and local settings | `~/.mac-alert/config` | Mode `600`; parsed as data, never sourced as shell code |
| SMTP app password | macOS login Keychain | Read only at send time by the SMTP helper |
| Webcam photo and queued alert | `~/.mac-alert` and `~/.mac-alert/pending` | Private directory mode `700`, files mode `600`, age and count limits |
| Running automation | Per-user LaunchAgents | Plist files mode `600`; runs only after user login |

## Controls reviewed

- **No shell execution from configuration:** only a fixed allow-list of keys
  is accepted. Quoted values are never evaluated a second time.
- **No credential in process arguments:** Telegram uses a private `curl`
  configuration passed through standard input. The SMTP password is retrieved
  by the Python helper from Keychain and is never passed from the shell.
- **Private chat selection:** the setup helper matches a unique phrase sent by
  the owner and matching private sender/chat IDs, rather than choosing an
  arbitrary item from the bot update list.
- **TLS for SMTP:** direct mail uses TLS through `smtps://` or STARTTLS through
  `smtp://`, with certificate verification from the macOS trust store.
- **Bounded operations:** network probe, camera capture, Keychain lookup, and
  SMTP delivery have deadlines. The one-time Keychain consent is allowed up to
  one minute; failed delivery is queued instead of leaving a Shortcut
  indefinitely running.
- **Privacy choices:** webcam capture and public-IP lookup can each be
  disabled locally. Trusted public IPs merely label a network; no geolocation
  service is used.
- **Uninstall:** `uninstall.sh --purge-keychain` removes project files,
  LaunchAgents, the local queue, and the matching SMTP Keychain item.

## Verification performed

`zsh tests/verify.sh` passes and checks shell/Python syntax, plist structure,
lock-monitor compilation, safe parsing of valid configuration, and inert
handling of shell-looking configuration text. Manual acceptance tests on the
development Mac confirmed Telegram text/photo delivery, direct Gmail SMTP
delivery, a complete photo attachment, the trusted home-network label, and
the locked-session power-transition alert.

## Residual limitations

- A person who has access to the unlocked macOS account can read or alter the
  project files and may be able to use credentials accessible to that account.
- The project cannot alert before first login after a restart, or reliably
  while deep sleep prevents user processes and networking from running.
- Telegram, the configured mail provider, and optional public-IP lookup
  receive the enabled alert data. Their retention and account security are
  outside this project.
- The uninstaller cannot erase remote messages, cloud backups, macOS logs, or
  Shortcut/TCC records managed by other systems. See [UNINSTALL.md](UNINSTALL.md).

## Before enabling on another Mac

1. Download from a trusted source and run `zsh tests/verify.sh`.
2. Use a dedicated Telegram bot and an app password rather than a main email
   password.
3. Complete the manual test matrix in [USAGE.md](USAGE.md).
4. Review `config.example` and choose whether to disable photo or public-IP
   collection.
