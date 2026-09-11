# Installation for first-time Terminal users

This guide is written for someone who has never used Terminal. It installs the
project files only; Telegram, email, permissions, and monitoring are set up in
[SETUP.md](SETUP.md) afterwards.

> [!NOTE]
> Mac Anti-Theft Alert was developed and tested only on **macOS 27**. It runs
> for the currently signed-in macOS user and is not a graphical application in
> the Applications folder.

## Before you begin

You need:

- A Mac running macOS 27 and an administrator account for the one Apple tools
  installation below.
- An internet connection.
- About 10 minutes without locking or restarting the Mac.
- Telegram and an email address. These are configured later.

Terminal is the macOS application where you type short commands. Commands in
this guide are safe to copy exactly as shown. Press `Return` after each one.

## 1. Download the ZIP file

1. Go to the [project page](https://github.com/Bat73300/mac-anti-theft-alert).
2. Click the green **Code** button.
3. Click **Download ZIP**.
4. Open Finder, then **Downloads**.
5. Double-click `mac-anti-theft-alert-main.zip`. Finder creates a folder named
   `mac-anti-theft-alert-main`. Leave this folder in Downloads for now.

Do not place Telegram tokens, app passwords, or your completed configuration
inside this downloaded folder.

## 2. Open Terminal in the downloaded folder

1. Press `Command` + `Space`, type **Terminal**, then press `Return`.
2. In Terminal, type `cd` followed by one space. Do not press `Return` yet.
3. Drag the `mac-anti-theft-alert-main` folder from Finder into the Terminal
   window. macOS writes its exact location for you.
4. Press `Return`.
5. Run:

   ```sh
   ls
   ```

You should see names including `install.sh`, `README.md`, `docs`, and `tests`.
If you do not, repeat this section and make sure you dragged the extracted
folder, rather than the ZIP file or the Downloads folder.

## 3. Install Apple Command Line Tools

The project compiles a very small local monitor that tracks whether the
already-open session is locked. Apple provides the required compiler in its
free **Command Line Tools for Xcode** package; you do not need the full Xcode
application.

Run:

```sh
xcode-select --install
```

A macOS window appears. Choose **Install**, accept Apple's license, and wait
until it finishes. If macOS says the tools are already installed, continue.

The project installer checks for the tools before changing anything. If they
are missing, it stops cleanly and prints this same command.

## 4. Choose optional helpers

### Webcam photo

Alerts can work without a photo. To include one, install Homebrew first from
[brew.sh](https://brew.sh/), then run:

```sh
brew install imagesnap
imagesnap -h
```

The second command confirms that the camera helper is available. A missing
camera helper or denied camera permission results in a text-only alert.

### Direct email without Mail.app, or automatic Telegram chat-ID setup

Python 3 is needed only for direct SMTP email and the helper that securely
finds your Telegram private chat ID. Mail.app email delivery does not need it.
If you will use either of those features, install Python through Homebrew:

```sh
brew install python
python3 --version
```

## 5. Verify the downloaded files

Before adding any credentials, run:

```sh
zsh tests/verify.sh
```

Expected final line:

```text
mac-alert: offline verification passed.
```

This check never opens the camera, contacts Telegram, sends email, or reads a
password. It validates shell files, plist files, the local lock monitor, and
safe configuration parsing. When Python is installed, it checks the Python
helpers too.

## 6. Install the project files

Run:

```sh
zsh install.sh
```

Expected result: Terminal says that files are ready and creates
`~/.mac-alert/config`. Monitoring is **not** active yet, so no alert can be
sent at this stage.

Continue with [SETUP.md](SETUP.md). That guide creates the bot, configures
delivery, runs one deliberate test alert, and only then enables monitoring.

## Where files are installed

The Downloads folder remains the project source: keep it while the project is
installed, so it is available for updates, verification, and removal.

The active per-user installation is kept outside `/Applications` because it
contains private settings and runs only for the signed-in user:

| Location | Contents |
| --- | --- |
| `~/.mac-alert` | Private configuration, scripts, queue, photos, and lock state |
| `~/Library/LaunchAgents` | Two macOS per-user automation definitions |

This is the standard macOS layout for a per-user script and LaunchAgent. It
does not affect other user accounts on the Mac.

## Updating later

Download and extract a new ZIP, open Terminal in its extracted folder using
step 2, then run:

```sh
zsh install.sh --enable
```

Your existing `~/.mac-alert/config`, Telegram settings, and Keychain password
are retained. Run the setup test again after an update that changes delivery
or camera behavior.

## Common problems

| What you see | What to do |
| --- | --- |
| `zsh: no such file or directory: install.sh` | Terminal is in the wrong folder. Repeat step 2, then run `ls` and check that `install.sh` is listed. |
| `Apple Command Line Tools are required` | Run `xcode-select --install`, finish Apple's installation, then rerun `zsh install.sh`. |
| `brew: command not found` | Install Homebrew from [brew.sh](https://brew.sh/), close and reopen Terminal, then repeat the optional helper command. |
| `Python 3 is required` | Run `brew install python`, then repeat the SMTP setup or Telegram chat-ID step. |
| `imagesnap is not installed` | Run `brew install imagesnap`, or continue with text-only alerts. |
| A camera, Keychain, Mail, or Shortcuts prompt appears | Read it and approve only if it names the expected app or item. [SETUP.md](SETUP.md) explains each expected prompt. |
| Telegram says that the bot cannot send messages to the bot | You used the bot's numerical ID. Send **Start** and a unique phrase to the bot, then use the chat-ID helper described in [SETUP.md](SETUP.md). |

After setup, use the read-only diagnostic:

```sh
~/.mac-alert/mac-alert-doctor.sh
```

It checks local settings and permissions without sending an alert, opening the
camera, contacting the network, or reading a Keychain password.
