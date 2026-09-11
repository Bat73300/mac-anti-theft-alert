# Changelog

## Unreleased

- Check for Apple Command Line Tools before installation changes files.
- Support Python 3 from standard Homebrew locations instead of assuming it is
  bundled with macOS, and explain when it is required.
- Add an explicit, opt-in setup test that runs the real Shortcut once so users
  can approve and verify delivery and macOS privacy prompts.
- Clarifies the public README's supported macOS version, user-session modes,
  startup behaviour, privacy scope, and setup path. Adds a transparent note
  about AI-assisted development to the contribution guide.
- Replaces the incompatible Linux ShellCheck workflow with macOS verification
  that runs the repository's offline test suite on the platform the project
  supports.
- Adds `mac-alert-doctor.sh`, a read-only setup diagnostic that checks the
  private configuration, Shortcut, optional camera helper, LaunchAgents, and
  lock-state initialization without sending an alert or reading a Keychain
  password.
- Adds contributor guidance, privacy-safe issue templates, and a documented
  release checklist.

All notable changes to this project are documented in this file.

## 1.1.0 — 2026-09-10

- Adds direct TLS/STARTTLS SMTP delivery through the macOS Python runtime. App
  passwords stay in the login Keychain and photo MIME encoding is handled by
  the standard library.
- Adds a bounded network probe, camera timeout, and SMTP timeout so a Shortcut
  can return even when a dependency is unavailable.
- Adds offline verification, installation/setup/usage/uninstall guides, and a
  dry-run uninstaller with optional Keychain removal.
- Adds Always, Locked only, and Off monitoring modes, with a fail-closed lock
  state after a restart or re-enabling locked-only mode.
- Makes webcam capture optional, adds timestamped photo filenames, and retries
  both Telegram and direct-SMTP delivery from the private local queue.
- Requires a unique owner phrase when selecting a Telegram chat ID, preventing
  accidental use of a bot ID, group, or unrelated update.

## 1.0.0 — 2026-09-10

Initial public release.

- Detects battery-to-AC power transitions through a per-user LaunchAgent.
- Sends alert text and a webcam photo through Telegram and Mail.app.
- Includes trusted public-IP labels and a local Telegram retry queue.
- Documents setup, privacy considerations, troubleshooting, and known limitations.
