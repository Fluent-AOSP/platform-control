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
Usage: scripts/telegram-notify.sh [options]

Send one low-noise Fluent AOSP status notification through a configured Telegram
bot. Messages use plain text; no Markdown/HTML is interpreted.

Options:
  --title TEXT       Required notification title
  --message TEXT     Optional detail text
  --level LEVEL      info|success|warning|failure (default: info)
  --photo FILE       Attach one sanitized PNG/JPEG screenshot
  --config FILE      Secret config path
  --test             Send the standard configuration test message
  --dry-run          Validate arguments without reading secrets or using network
  --help             Show this help

Environment:
  TELEGRAM_CONFIG          Default: ~/.config/fluent-aosp/telegram.conf
  TELEGRAM_HOST_LABEL      Default: hostname
  TELEGRAM_CONNECT_TIMEOUT Default: 10 seconds
  TELEGRAM_REQUEST_TIMEOUT Default: 30 seconds
  TELEGRAM_RETRIES         Default: 2

The config is parsed as data (never sourced) and must be owned by the current
user with no group/other permissions:

  BOT_TOKEN=<BotFather token>
  CHAT_ID=<numeric Telegram chat id>
EOF
}

title=
message=
level=info
photo=
photo_fd=
photo_upload=
photo_mime=
photo_ext=
config=${TELEGRAM_CONFIG:-$(telegram_default_config)}
dry_run=0
test_mode=0

while (( $# )); do
  case "$1" in
    --title) [[ $# -ge 2 ]] || die '--title requires a value'; title=$2; shift 2 ;;
    --message) [[ $# -ge 2 ]] || die '--message requires a value'; message=$2; shift 2 ;;
    --level) [[ $# -ge 2 ]] || die '--level requires a value'; level=$2; shift 2 ;;
    --photo) [[ $# -ge 2 ]] || die '--photo requires a value'; photo=$2; shift 2 ;;
    --config) [[ $# -ge 2 ]] || die '--config requires a value'; config=$2; shift 2 ;;
    --test) test_mode=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$level" in
  info|success|warning|failure) ;;
  *) die '--level must be info, success, warning, or failure' ;;
esac

if [[ "$test_mode" == 1 ]]; then
  [[ -z "$title" ]] && title='Fluent AOSP notifications configured'
  [[ -z "$message" ]] && message='Telegram delivery is working. Future messages are limited to meaningful build, boot, test-loop, and feedback milestones.'
  level=success
fi

[[ -n "$title" ]] || die '--title is required'
(( ${#title} <= 240 )) || die 'title is longer than 240 characters'
(( ${#message} <= 3000 )) || die 'message is longer than 3000 characters'
if [[ -n "$photo" ]]; then
  [[ -f "$photo" && ! -L "$photo" ]] || die "photo must be a regular non-symlink file: $photo"
  case "${photo,,}" in
    *.png) photo_ext=png; photo_mime=image/png ;;
    *.jpg|*.jpeg) photo_ext=jpg; photo_mime=image/jpeg ;;
    *) die 'photo must use .png, .jpg, or .jpeg' ;;
  esac
  photo_dir=${photo%/*}
  [[ "$photo_dir" != "$photo" ]] || photo_dir=.
  [[ -d "$photo_dir" ]] || die "photo parent is not a directory: $photo_dir"
  [[ $(stat -Lc '%u' -- "$photo_dir") == "$EUID" ]] || die 'photo parent must be owned by the current user'
  photo_dir_mode=$(stat -Lc '%a' -- "$photo_dir")
  (( (8#$photo_dir_mode & 022) == 0 )) || die 'photo parent must not be group/other writable'

  exec {photo_fd}<"$photo"
  photo_fd_path="/proc/$$/fd/$photo_fd"
  IFS='|' read -r photo_type photo_owner photo_mode photo_size fd_identity \
    < <(stat -Lc '%F|%u|%a|%s|%d:%i' -- "$photo_fd_path")
  [[ "$photo_type" == 'regular file' ]] || die 'photo descriptor is not a regular file'
  [[ "$photo_owner" == "$EUID" ]] || die 'photo must be owned by the current user'
  (( (8#$photo_mode & 022) == 0 )) || die 'photo must not be group/other writable'
  (( photo_size <= 10000000 )) || die 'photo exceeds the 10 MB Bot API upload limit used by this script'
  path_identity=$(stat -Lc '%d:%i' -- "$photo")
  if [[ -L "$photo" || "$path_identity" != "$fd_identity" ]]; then
    die "photo changed while it was being opened: $photo"
  fi
  photo_magic=$(od -An -tx1 -N8 -- "$photo_fd_path" | tr -d '[:space:]')
  case "$photo_ext:$photo_magic" in
    png:89504e470d0a1a0a | jpg:ffd8ff*) ;;
    *) die "photo content does not match its .$photo_ext extension" ;;
  esac
  # Curl opens the already-validated descriptor, not the mutable source path.
  photo_upload=$photo_fd_path
fi

host_label=${TELEGRAM_HOST_LABEL:-$(hostname)}
(( ${#host_label} <= 128 )) || die 'TELEGRAM_HOST_LABEL is longer than 128 characters'
case "$level" in
  info) icon='ℹ️' ;;
  success) icon='✅' ;;
  warning) icon='⚠️' ;;
  failure) icon='❌' ;;
esac
text="$icon $title"
[[ -z "$message" ]] || text+=$'\n\n'"$message"
text+=$'\n\n'"Host: $host_label"
text+=$'\n'"UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
(( ${#text} <= 3800 )) || die 'rendered Telegram message is too long'

if [[ "$dry_run" == 1 ]]; then
  printf 'DRY-RUN: Telegram level=%q title=%q photo=%q config=%q (secret not read; network not used)\n' \
    "$level" "$title" "$photo" "$config"
  exit 0
fi

require_command jq
telegram_load_config "$config" || exit 1
response=
if [[ -n "$photo" && ${#text} -le 900 ]]; then
  if ! response=$(telegram_api "$TELEGRAM_BOT_TOKEN" sendPhoto \
    --request POST \
    --form-string "chat_id=$TELEGRAM_CHAT_ID" \
    --form-string "caption=$text" \
    --form "photo=@$photo_upload;filename=fluent-aosp.$photo_ext;type=$photo_mime"); then
    printf 'Telegram sendPhoto failed: %s\n' "$(telegram_error_description "$response")" >&2
    exit 1
  fi
else
  if ! response=$(telegram_api "$TELEGRAM_BOT_TOKEN" sendMessage \
    --request POST \
    --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
    --data-urlencode "text=$text" \
    --data-urlencode 'disable_web_page_preview=true'); then
    printf 'Telegram sendMessage failed: %s\n' "$(telegram_error_description "$response")" >&2
    exit 1
  fi
  if [[ -n "$photo" ]]; then
    if ! response=$(telegram_api "$TELEGRAM_BOT_TOKEN" sendPhoto \
      --request POST \
      --form-string "chat_id=$TELEGRAM_CHAT_ID" \
      --form-string "caption=$icon $title" \
      --form "photo=@$photo_upload;filename=fluent-aosp.$photo_ext;type=$photo_mime"); then
      printf 'Telegram message sent, but photo upload failed: %s\n' "$(telegram_error_description "$response")" >&2
      exit 1
    fi
  fi
fi

jq -e '.ok == true' <<<"$response" >/dev/null || {
  printf 'Telegram API rejected the request: %s\n' "$(jq -r '.description // "unknown error"' <<<"$response")" >&2
  exit 1
}
printf 'Telegram notification sent (message_id=%s).\n' "$(jq -r '.result.message_id // "unknown"' <<<"$response")"
[[ -z "$photo_fd" ]] || exec {photo_fd}<&-
unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
