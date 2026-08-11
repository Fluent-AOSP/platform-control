#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/aosp-init-sync.sh [--dry-run] [--help]

Verify the approved Android 17 manifest ref, initialize/sync AOSP, and export a
revision-locked manifest. This never cleans an existing checkout.

Environment:
  AOSP_ROOT                    Source path (default: /mnt/aosp)
  MANIFEST_URL                 Default: https://android.googlesource.com/platform/manifest
  MANIFEST_BRANCH              Default: android17-release
  EXPECTED_MANIFEST_REF        Default: 29ace668ae756c7b8917c57abb440f6518844b0c
  REPO_REV                     Repo launcher ref (default: v2.54)
  SYNC_JOBS                    Network fetch jobs; default: 4
  CHECKOUT_JOBS                Local checkout jobs; default: 1
  SYNC_TIMEOUT                 Per-stage limit; default: 21600 seconds
  SYNC_ATTEMPTS                Bounded sync attempts; default: 4
  SYNC_RETRY_DELAY             Linear backoff base; default: 120 seconds
  LOCK_FILE                    Default: manifests/aosp-android17.lock.xml in this repo
  ALLOW_MANIFEST_REF_ADVANCE  1 permits the named branch to differ from the observed ref
  ALLOW_MANIFEST_LOCK_UPDATE  1 permits replacing a different existing lock file

Dry-run prints commands and performs no network or filesystem mutation.
EOF
}

DRY_RUN=0
case ${1:-} in
  '') ;;
  --dry-run) DRY_RUN=1 ;;
  --help|-h) usage; exit 0 ;;
  *) die "unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'too many arguments'

AOSP_ROOT=${AOSP_ROOT:-/mnt/aosp}
MANIFEST_URL=${MANIFEST_URL:-https://android.googlesource.com/platform/manifest}
MANIFEST_BRANCH=${MANIFEST_BRANCH:-android17-release}
EXPECTED_MANIFEST_REF=${EXPECTED_MANIFEST_REF:-29ace668ae756c7b8917c57abb440f6518844b0c}
REPO_REV=${REPO_REV:-v2.54}
SYNC_JOBS=${SYNC_JOBS:-4}
CHECKOUT_JOBS=${CHECKOUT_JOBS:-1}
SYNC_TIMEOUT=${SYNC_TIMEOUT:-21600}
SYNC_ATTEMPTS=${SYNC_ATTEMPTS:-4}
SYNC_RETRY_DELAY=${SYNC_RETRY_DELAY:-120}
LOCK_FILE=${LOCK_FILE:-$REPO_ROOT/manifests/aosp-android17.lock.xml}
ALLOW_MANIFEST_REF_ADVANCE=${ALLOW_MANIFEST_REF_ADVANCE:-0}
ALLOW_MANIFEST_LOCK_UPDATE=${ALLOW_MANIFEST_LOCK_UPDATE:-0}

require_positive_integer SYNC_JOBS "$SYNC_JOBS"
require_positive_integer CHECKOUT_JOBS "$CHECKOUT_JOBS"
require_positive_integer SYNC_TIMEOUT "$SYNC_TIMEOUT"
require_positive_integer SYNC_ATTEMPTS "$SYNC_ATTEMPTS"
require_positive_integer SYNC_RETRY_DELAY "$SYNC_RETRY_DELAY"
[[ "$EXPECTED_MANIFEST_REF" =~ ^[0-9a-f]{40}$ ]] || die 'EXPECTED_MANIFEST_REF must be a 40-character lowercase Git object ID'
[[ "$ALLOW_MANIFEST_REF_ADVANCE" == 0 || "$ALLOW_MANIFEST_REF_ADVANCE" == 1 ]] || die 'ALLOW_MANIFEST_REF_ADVANCE must be 0 or 1'
[[ "$ALLOW_MANIFEST_LOCK_UPDATE" == 0 || "$ALLOW_MANIFEST_LOCK_UPDATE" == 1 ]] || die 'ALLOW_MANIFEST_LOCK_UPDATE must be 0 or 1'

if [[ "$DRY_RUN" == 1 ]]; then
  quote_command git ls-remote --heads "$MANIFEST_URL" "refs/heads/$MANIFEST_BRANCH"
  quote_command install -d -m 0755 "$AOSP_ROOT"
  printf 'DRY-RUN: (cd %q && ' "$AOSP_ROOT"
  printf '%q ' repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --repo-rev "$REPO_REV" --no-clone-bundle --no-use-superproject
  printf ')\n'
  printf 'DRY-RUN: (cd %q && ' "$AOSP_ROOT"
  printf '%q ' timeout "$SYNC_TIMEOUT" repo sync --network-only --no-use-superproject -c --no-clone-bundle --optimized-fetch --prune --fail-fast -j "$SYNC_JOBS"
  printf ')\n'
  printf 'DRY-RUN: retry failed network fetch up to %q times with linear backoff base %q seconds\n' \
    "$SYNC_ATTEMPTS" "$SYNC_RETRY_DELAY"
  printf 'DRY-RUN: (cd %q && ' "$AOSP_ROOT"
  printf '%q ' timeout "$SYNC_TIMEOUT" repo sync --local-only --no-use-superproject --fail-fast -j "$CHECKOUT_JOBS"
  printf ')\n'
  printf 'DRY-RUN: require a clean repo status before lock export\n'
  printf 'DRY-RUN: export revision manifest, remove the disabled superproject, normalize trailing whitespace, compare, then atomically install %q\n' "$LOCK_FILE"
  exit 0
fi

require_command git
require_command repo
require_command timeout
require_command cmp
require_command mktemp
require_command python3

notification_sent=0
tmp_lock=
tmp_status=
sync_cleanup() {
  local status=$?
  trap - EXIT INT TERM
  [[ -z "$tmp_lock" ]] || rm -f -- "$tmp_lock"
  [[ -z "$tmp_status" ]] || rm -f -- "$tmp_status"
  if (( status != 0 )) && [[ "$notification_sent" == 0 ]]; then
    notify_telegram_safe failure 'AOSP source sync failed' \
      "The $MANIFEST_BRANCH sync exited with status $status at $AOSP_ROOT. Review the current terminal/sync log before retrying."
  fi
  exit "$status"
}
trap sync_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

remote_line=$(git ls-remote --heads "$MANIFEST_URL" "refs/heads/$MANIFEST_BRANCH")
remote_ref=${remote_line%%[[:space:]]*}
[[ "$remote_ref" =~ ^[0-9a-f]{40}$ ]] || die "could not resolve refs/heads/$MANIFEST_BRANCH from $MANIFEST_URL"
if [[ "$remote_ref" != "$EXPECTED_MANIFEST_REF" ]]; then
  if [[ "$ALLOW_MANIFEST_REF_ADVANCE" != 1 ]]; then
    die "manifest ref changed: expected $EXPECTED_MANIFEST_REF, observed $remote_ref; review and set ALLOW_MANIFEST_REF_ADVANCE=1 explicitly"
  fi
  warn "allowing reviewed manifest branch advancement: $EXPECTED_MANIFEST_REF -> $remote_ref"
fi

install -d -m 0755 "$AOSP_ROOT"
if find "$AOSP_ROOT" -mindepth 1 -maxdepth 1 ! -name .repo -print -quit | grep -q . && [[ ! -d "$AOSP_ROOT/.repo" ]]; then
  die "$AOSP_ROOT is non-empty and is not a Repo checkout; refusing to initialize"
fi

(
  cd "$AOSP_ROOT"
  repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --repo-rev "$REPO_REV" --no-clone-bundle --no-use-superproject
  sync_status=1
  for (( sync_attempt = 1; sync_attempt <= SYNC_ATTEMPTS; sync_attempt++ )); do
    log "AOSP network sync attempt $sync_attempt/$SYNC_ATTEMPTS (jobs=$SYNC_JOBS)"
    if timeout "$SYNC_TIMEOUT" repo sync --network-only --no-use-superproject -c --no-clone-bundle --optimized-fetch --prune --fail-fast -j "$SYNC_JOBS"; then
      sync_status=0
      break
    else
      sync_status=$?
    fi
    if (( sync_attempt == SYNC_ATTEMPTS )); then
      break
    fi
    retry_delay=$((SYNC_RETRY_DELAY * sync_attempt))
    warn "AOSP network sync attempt $sync_attempt failed with status $sync_status; retrying in ${retry_delay}s"
    sleep "$retry_delay"
  done
  (( sync_status == 0 )) || exit "$sync_status"
  log "AOSP local checkout (jobs=$CHECKOUT_JOBS)"
  timeout "$SYNC_TIMEOUT" repo sync --local-only --no-use-superproject --fail-fast -j "$CHECKOUT_JOBS"
)

tmp_status=$(mktemp "${TMPDIR:-/tmp}/aosp-repo-status.XXXXXX")
(
  cd "$AOSP_ROOT"
  repo status >"$tmp_status"
)
if grep -q '^project ' "$tmp_status"; then
  head -100 "$tmp_status" >&2
  die 'AOSP checkout is not clean after sync; refusing to export a lock'
fi
rm -f -- "$tmp_status"
tmp_status=

lock_parent=$(dirname -- "$LOCK_FILE")
install -d -m 0755 "$lock_parent"
tmp_lock=$(mktemp "$lock_parent/.aosp-lock.XXXXXX")
(
  cd "$AOSP_ROOT"
  repo manifest -r -o "$tmp_lock"
)
[[ -s "$tmp_lock" ]] || die 'Repo exported an empty lock manifest'
python3 - "$tmp_lock" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
lines = [line.rstrip() for line in lines if not re.match(r"^\s*<superproject\b", line)]
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

if [[ -e "$LOCK_FILE" ]] && ! cmp -s "$tmp_lock" "$LOCK_FILE"; then
  [[ "$ALLOW_MANIFEST_LOCK_UPDATE" == 1 ]] || die "lock file differs; review $tmp_lock and rerun with ALLOW_MANIFEST_LOCK_UPDATE=1"
fi
if [[ ! -e "$LOCK_FILE" ]] || ! cmp -s "$tmp_lock" "$LOCK_FILE"; then
  mv -- "$tmp_lock" "$LOCK_FILE"
else
  rm -f -- "$tmp_lock"
fi
chmod 0644 "$LOCK_FILE"
tmp_lock=

notify_telegram_safe success 'AOSP source sync completed' \
  "The $MANIFEST_BRANCH checkout completed and a revision lock was written to $LOCK_FILE."
notification_sent=1
log "sync complete; locked manifest: $LOCK_FILE"
