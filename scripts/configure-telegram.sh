#!/usr/bin/env bash
# Secret-handling entry point: never allow inherited or command-line xtrace.
{ set +x; } 2>/dev/null
set -Eeuo pipefail
umask 077
ulimit -c 0 2>/dev/null || true
unset token TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID TELEGRAM_BOT_USERNAME 2>/dev/null || true

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"

usage() {
  cat <<'EOF'
Usage: scripts/configure-telegram.sh [options]

Interactively store a BotFather token in a mode-0600 file, discover/confirm one
private chat, and send a test notification. The token is read silently from the
controlling terminal and is never accepted as a command-line argument.

Options:
  --config FILE    Config path (default: ~/.config/fluent-aosp/telegram.conf)
  --chat-id ID     Use a known numeric private-chat ID instead of getUpdates
  --force          Replace an existing config
  --help           Show this help

Before discovery, open the bot in Telegram and send it /start. A bot cannot
initiate a private conversation until you do this.
EOF
}

config=${TELEGRAM_CONFIG:-$(telegram_default_config)}
chat_id=
force=0
while (( $# )); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config requires a value'; config=$2; shift 2 ;;
    --chat-id) [[ $# -ge 2 ]] || die '--chat-id requires a value'; chat_id=$2; shift 2 ;;
    --force) force=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command curl
require_command jq
if ! exec {tty_fd}<>/dev/tty; then
  die 'run this setup from an interactive terminal so the token can be entered silently'
fi
[[ ! -e "$config" || "$force" == 1 ]] || die "config already exists: $config (use --force to replace it)"
[[ -z "$chat_id" || "$chat_id" =~ ^[1-9][0-9]*$ ]] || die '--chat-id must be a positive private-chat ID'

printf 'Paste the BotFather token (input will be hidden): ' >&"$tty_fd"
IFS= read -r -s token <&"$tty_fd"
printf '\n' >&"$tty_fd"
telegram_validate_token "$token" || die 'the entered token does not match Telegram bot-token format'

response=
if ! response=$(telegram_api "$token" getMe --request POST); then
  description=$(telegram_error_description "$response")
  unset token
  die "Telegram getMe failed: $description"
fi
jq -e '.ok == true' <<<"$response" >/dev/null || {
  description=$(jq -r '.description // "unknown error"' <<<"$response")
  unset token
  die "Telegram rejected the token: $description"
}
bot_username=$(jq -r '.result.username' <<<"$response")
bot_name=$(jq -r '.result.first_name' <<<"$response")
printf 'Verified bot: %s (@%s)\n' "$bot_name" "$bot_username"

if [[ -z "$chat_id" ]]; then
  printf '\n1. Open https://t.me/%s\n2. Tap Start or send /start\n3. Return here and press Enter.\n' "$bot_username"
  IFS= read -r _ <&"$tty_fd"

  if ! response=$(telegram_api "$token" getUpdates \
    --request POST \
    --data-urlencode 'offset=-100' \
    --data-urlencode 'limit=100' \
    --data-urlencode 'timeout=0' \
    --data-urlencode 'allowed_updates=["message","edited_message"]'); then
    description=$(telegram_error_description "$response")
    unset token
    die "Telegram getUpdates failed: $description. If this bot uses a webhook, rerun with --chat-id."
  fi
  jq -e '.ok == true' <<<"$response" >/dev/null || {
    description=$(jq -r '.description // "unknown error"' <<<"$response")
    unset token
    die "Telegram getUpdates was rejected: $description"
  }

  mapfile -t candidates < <(jq -r '
    [.result[] | (.message // .edited_message // empty).chat | select(.type == "private")]
    | unique_by(.id)
    | .[]
    | [.id, (.username // ""), (.first_name // ""), (.last_name // "")]
    | @tsv
  ' <<<"$response")

  case ${#candidates[@]} in
    0)
      unset token
      die "no private chat update was found for @$bot_username; send /start, wait a few seconds, and rerun"
      ;;
    1)
      IFS=$'\t' read -r candidate_id candidate_user candidate_first candidate_last <<<"${candidates[0]}"
      printf 'Found private chat: id=%s user=@%s name=%s %s\n' \
        "$candidate_id" "${candidate_user:-unknown}" "$candidate_first" "$candidate_last"
      printf 'Use this destination? [y/N] ' >&"$tty_fd"
      IFS= read -r answer <&"$tty_fd"
      [[ "$answer" == y || "$answer" == Y || "$answer" == yes || "$answer" == YES ]] || {
        unset token
        die 'destination was not confirmed'
      }
      chat_id=$candidate_id
      ;;
    *)
      printf 'Multiple private chats have contacted this bot:\n'
      printf '  %s\n' "${candidates[@]}"
      printf 'Enter the intended numeric chat ID: ' >&"$tty_fd"
      IFS= read -r chat_id <&"$tty_fd"
      [[ "$chat_id" =~ ^[1-9][0-9]*$ ]] || {
        unset token
        die 'chat ID must be numeric'
      }
      if ! printf '%s\n' "${candidates[@]}" | cut -f1 | grep -Fxq -- "$chat_id"; then
        unset token
        die 'the selected ID was not one of the discovered private chats'
      fi
      ;;
  esac
fi

config_dir=$(dirname -- "$config")
if [[ ! -e "$config_dir" ]]; then
  install -d -m 0700 "$config_dir"
fi
[[ -d "$config_dir" ]] || { unset token; die "config parent is not a directory: $config_dir"; }
[[ $(stat -Lc '%u' -- "$config_dir") == "$EUID" ]] || {
  unset token
  die "config parent must be owned by uid $EUID: $config_dir"
}
config_dir_mode=$(stat -Lc '%a' -- "$config_dir")
(( (8#$config_dir_mode & 022) == 0 )) || {
  unset token
  die "config parent must not be group/other writable: $config_dir"
}
[[ ! -L "$config" ]] || { unset token; die "refusing to replace symlink: $config"; }
tmp_config=$(mktemp "$config_dir/.telegram.conf.XXXXXX")
cleanup_tmp() { rm -f -- "$tmp_config"; }
trap cleanup_tmp EXIT
printf 'BOT_TOKEN=%s\nCHAT_ID=%s\n' "$token" "$chat_id" >"$tmp_config"
chmod 0600 "$tmp_config"
mv -f -- "$tmp_config" "$config"
trap - EXIT
chmod 0600 "$config"
unset token
exec {tty_fd}>&-

telegram_check_config_permissions "$config"
printf 'Stored Telegram credentials in %s (mode %s).\n' "$config" "$(stat -c '%a' "$config")"
"$SCRIPT_DIR/telegram-notify.sh" --config "$config" --test
