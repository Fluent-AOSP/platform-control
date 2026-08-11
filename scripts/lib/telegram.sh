#!/usr/bin/env bash
# Telegram Bot API helpers. Callers must enable strict mode themselves.

# Never propagate credentials that happened to be exported by a parent shell.
unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID TELEGRAM_BOT_USERNAME 2>/dev/null || true

telegram_default_config() {
  printf '%s/fluent-aosp/telegram.conf\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

telegram_validate_token() {
  [[ "$1" =~ ^[0-9]{5,}:[A-Za-z0-9_-]{20,}$ ]]
}

telegram_validate_chat_id() {
  # This project intentionally supports private chats only. Telegram user IDs
  # are positive; groups, supergroups, and channels use negative IDs.
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

telegram_check_config_permissions() {
  local config=$1 config_dir mode owner dir_mode dir_owner
  [[ -f "$config" && ! -L "$config" ]] || {
    printf 'Telegram config must be a regular, non-symlink file: %s\n' "$config" >&2
    return 1
  }
  owner=$(stat -Lc '%u' -- "$config") || return 1
  [[ "$owner" == "$EUID" ]] || {
    printf 'Telegram config must be owned by uid %s: %s\n' "$EUID" "$config" >&2
    return 1
  }
  mode=$(stat -Lc '%a' -- "$config") || return 1
  # Reject every group/other permission. Owner may use 400 or 600.
  (( (8#$mode & 077) == 0 )) || {
    printf 'Telegram config exposes group/other permissions (%s); run chmod 600 %q\n' "$mode" "$config" >&2
    return 1
  }

  # A secure file in a writable parent can still be replaced between checking
  # and opening. Require the immediate parent to be private to this UID.
  config_dir=${config%/*}
  [[ "$config_dir" != "$config" ]] || config_dir=.
  [[ -d "$config_dir" ]] || {
    printf 'Telegram config parent is not a directory: %s\n' "$config_dir" >&2
    return 1
  }
  dir_owner=$(stat -Lc '%u' -- "$config_dir") || return 1
  dir_mode=$(stat -Lc '%a' -- "$config_dir") || return 1
  [[ "$dir_owner" == "$EUID" ]] || {
    printf 'Telegram config parent must be owned by uid %s: %s\n' "$EUID" "$config_dir" >&2
    return 1
  }
  (( (8#$dir_mode & 022) == 0 )) || {
    printf 'Telegram config parent must not be group/other writable (%s): %s\n' "$dir_mode" "$config_dir" >&2
    return 1
  }
}

telegram_load_config() {
  local config=$1 line key value config_fd expected_identity path_identity fd_identity
  local -a config_lines=()

  # Unsetting removes any inherited export attribute before secret assignment.
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID TELEGRAM_BOT_USERNAME 2>/dev/null || {
    printf 'Telegram credential variables must not be readonly\n' >&2
    return 1
  }
  TELEGRAM_BOT_TOKEN=
  TELEGRAM_CHAT_ID=
  telegram_check_config_permissions "$config" || return 1

  expected_identity=$(stat -Lc '%d:%i' -- "$config") || return 1
  exec {config_fd}<"$config" || return 1
  path_identity=$(stat -Lc '%d:%i' -- "$config") || {
    exec {config_fd}<&-
    return 1
  }
  fd_identity=$(stat -Lc '%d:%i' -- "/proc/$$/fd/$config_fd") || {
    exec {config_fd}<&-
    return 1
  }
  if [[ -L "$config" || "$expected_identity" != "$path_identity" || "$path_identity" != "$fd_identity" ]]; then
    printf 'Telegram config changed while it was being opened: %s\n' "$config" >&2
    exec {config_fd}<&-
    return 1
  fi
  mapfile -t config_lines <&"$config_fd"
  exec {config_fd}<&-

  for line in "${config_lines[@]}"; do
    line=${line%$'\r'}
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || {
      printf 'Malformed Telegram config line in %s\n' "$config" >&2
      return 1
    }
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      BOT_TOKEN)
        [[ -z "$TELEGRAM_BOT_TOKEN" ]] || {
          printf 'Duplicate BOT_TOKEN in %s\n' "$config" >&2
          return 1
        }
        TELEGRAM_BOT_TOKEN=$value
        ;;
      CHAT_ID)
        [[ -z "$TELEGRAM_CHAT_ID" ]] || {
          printf 'Duplicate CHAT_ID in %s\n' "$config" >&2
          return 1
        }
        TELEGRAM_CHAT_ID=$value
        ;;
      *)
        printf 'Unknown Telegram config key %q in %s\n' "$key" "$config" >&2
        return 1
        ;;
    esac
  done

  telegram_validate_token "$TELEGRAM_BOT_TOKEN" || {
    printf 'BOT_TOKEN has an invalid format in %s\n' "$config" >&2
    return 1
  }
  telegram_validate_chat_id "$TELEGRAM_CHAT_ID" || {
    printf 'CHAT_ID has an invalid format in %s\n' "$config" >&2
    return 1
  }
}

telegram_error_description() {
  local response=${1-} description
  if [[ -n "$response" ]] && description=$(jq -er '.description // empty' <<<"$response" 2>/dev/null); then
    printf '%s\n' "$description"
  else
    printf 'transport error\n'
  fi
}

telegram_api() {
  local token=$1 method=$2
  shift 2
  local rc=0
  local -a retry_args=()
  # A local inherits the export attribute of an exported same-name global.
  export -n token 2>/dev/null || return 1

  telegram_validate_token "$token" || {
    printf 'Refusing Telegram request with an invalid token format\n' >&2
    return 1
  }
  [[ "$method" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || {
    printf 'Refusing invalid Telegram API method: %s\n' "$method" >&2
    return 1
  }
  command -v curl >/dev/null 2>&1 || {
    printf 'curl is required for Telegram notifications\n' >&2
    return 1
  }
  command -v env >/dev/null 2>&1 || {
    printf 'env is required for Telegram credential isolation\n' >&2
    return 1
  }

  # Retrying a send after its response was lost can duplicate a message/photo.
  # Only the setup-time read methods are safe to repeat automatically.
  case "$method" in
    getMe | getUpdates)
      retry_args=(--retry "${TELEGRAM_RETRIES:-2}" --retry-all-errors)
      ;;
  esac

  # Telegram requires the bot token in the URL. Feed that URL to curl's config
  # parser over stdin so the token appears neither in curl's argv nor in a
  # temporary file that could survive interruption. --disable must be curl's
  # first option so a user .curlrc cannot turn verbose tracing back on.
  printf 'url = "https://api.telegram.org/bot%s/%s"\n' "$token" "$method" |
    env -u token -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID -u TELEGRAM_BOT_USERNAME \
    curl --disable --config - \
      --silent --show-error --fail-with-body \
      --connect-timeout "${TELEGRAM_CONNECT_TIMEOUT:-10}" \
      --max-time "${TELEGRAM_REQUEST_TIMEOUT:-30}" \
      "${retry_args[@]}" \
      "$@" || rc=${PIPESTATUS[1]}
  return "$rc"
}
