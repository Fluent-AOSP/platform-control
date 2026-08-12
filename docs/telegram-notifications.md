# Telegram notifications

## Scope

Telegram is the user-feedback channel for meaningful unattended milestones only:

- AOSP source sync success/failure;
- AOSP image build success/failure;
- SDK Emulator smoke success/failure;
- locally built Cuttlefish verification success/failure;
- the first verified Quick Settings screenshot and explicit feedback request;
- one verified screenshot after each successful visible UI change batch.

Do not send per-command progress, raw log streams, bugreports, tokens, environment dumps, or screenshots from personal/development devices. An attachment is a raw Quick Settings screenshot—not redacted—from a new test-owned AOSP instance with no account or user data. The SDK loop attaches only after `WIPE_DATA=1`; the Cuttlefish loop attaches its first passing locally built baseline automatically. For later UI batches, send one representative expanded screenshot only after final validation rather than attaching every member of the repeated runtime pair.

## Private-chat setup

The selected configuration is a Bot API private chat with a local mode-0600 secret file.

1. Create a bot with Telegram's verified `@BotFather` and retain its token privately.
2. From an interactive terminal on this VM, run:

   ```bash
   cd /home/azureuser/fluent-aosp
   make telegram-configure
   ```

3. Paste the token at the hidden prompt.
4. Open the displayed `t.me/<bot>` link, tap **Start** or send `/start`, return to the terminal, and confirm the discovered private-chat identity.
5. Confirm the test message arrives.

The setup script never accepts a token as a command-line argument. It verifies the bot with `getMe`, inspects the most recent 100 updates for private chats, requires destination confirmation, writes atomically, enforces mode 0600, and sends a test. The negative update offset prevents an old backlog from hiding a newly sent `/start`; setup therefore acknowledges older pending updates. Use a dedicated bot and pass `--chat-id` if that bot is configured with a webhook.

Default credential path:

```text
~/.config/fluent-aosp/telegram.conf
```

Format (never commit a real file):

```text
BOT_TOKEN=<BotFather token>
CHAT_ID=<positive numeric private-chat id>
```

The parser treats this as data rather than sourcing it as shell code. The notifier refuses symlinks, files owned by another UID, group/other permissions, non-private (negative) chat IDs, and configuration files in a group/other-writable parent directory. It pins the checked configuration inode before reading it. Telegram necessarily authenticates bots with a token in the Bot API URL; the helper disables curl startup configuration and feeds that URL to curl's config parser over stdin so the token appears neither in curl's command line nor in a temporary file. Secret entry points disable shell xtrace and remove inherited credential export attributes before loading the file.

## Operation

```bash
make telegram-test
scripts/telegram-notify.sh \
  --level info \
  --title 'Fluent AOSP status' \
  --message 'A human decision is required.'
```

Optional screenshot:

```bash
scripts/telegram-notify.sh \
  --level success \
  --title 'Quick Settings baseline ready' \
  --message 'Please review this verified image.' \
  --photo /path/to/quick-settings.png
```

Plain text is used: user-controlled text is not interpreted as Markdown or HTML. Attachments are restricted to current-user-owned, non-symlink, non-writable-by-others PNG/JPEG files no larger than 10 MB, located in a current-user-owned directory that is not group/other writable. The notifier checks the image signature and uploads through the already validated file descriptor rather than reopening a mutable source path.

## Automatic hook policy

Operational scripts call the notifier through `notify_telegram_safe`:

- `NOTIFY_TELEGRAM=auto` (default): send only when the secret config exists;
- `NOTIFY_TELEGRAM=0`: suppress delivery for a run;
- `NOTIFY_TELEGRAM=1`: request delivery and warn if configuration is missing or broken.

Notification transport failure is recorded as a warning and never changes the primary sync/build/test result. Failure notifications include only the exit status and local evidence path. The first successfully delivered Cuttlefish feedback image creates `~/.local/state/fluent-aosp/first-cuttlefish-feedback.sent`; later passing runs send status text without an automatic image. After a visible UI batch is fully accepted, its orchestrator sends one representative screenshot explicitly with `--photo`. Remove the marker deliberately only to request a new automatic baseline attachment. Raw bugreports are never attached. Setup-time read calls may retry transient failures; `sendMessage` and `sendPhoto` are not automatically retried because repeating a POST after a lost response can create duplicates.

## Rotation and removal

- Rotate/revoke the token with `@BotFather`, then rerun `make telegram-configure` with `scripts/configure-telegram.sh --force`.
- Disable all automatic delivery with `NOTIFY_TELEGRAM=0`.
- Remove the local integration with:

  ```bash
  rm -f ~/.config/fluent-aosp/telegram.conf
  ```

No Telegram credential belongs in Git, shell history, CI logs, screenshots, issue trackers, or chat messages to coding agents.
