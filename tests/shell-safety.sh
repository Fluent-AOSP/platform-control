#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

scripts=(
  scripts/lib/common.sh
  scripts/lib/telegram.sh
  scripts/host-preflight.sh
  scripts/aosp-init-sync.sh
  scripts/aosp-build.sh
  scripts/sdk-emulator-smoke.sh
  scripts/cuttlefish-smoke.sh
  scripts/configure-telegram.sh
  scripts/telegram-notify.sh
)

for script in "${scripts[@]}"; do
  bash -n "$script"
done

entrypoints=(
  scripts/host-preflight.sh
  scripts/aosp-init-sync.sh
  scripts/aosp-build.sh
  scripts/sdk-emulator-smoke.sh
  scripts/cuttlefish-smoke.sh
  scripts/configure-telegram.sh
  scripts/telegram-notify.sh
)
for script in "${entrypoints[@]}"; do
  "$script" --help >/dev/null
done

# Dry-run entry points must succeed with deliberately nonexistent operational
# paths and must not create them.
sandbox=$(mktemp -d)
trap 'rm -rf -- "$sandbox"' EXIT
assert_not_contains() {
  local needle=$1 file=$2
  if grep -Fq -- "$needle" "$file"; then
    printf 'forbidden value %q found in %s\n' "$needle" "$file" >&2
    exit 1
  fi
}
missing_source="$sandbox/missing-source"
missing_out="$sandbox/missing-out"
missing_artifacts="$sandbox/missing-artifacts"

AOSP_ROOT="$missing_source" OUT_DIR="$missing_out" ARTIFACT_ROOT="$missing_artifacts" \
  scripts/aosp-init-sync.sh --dry-run >/dev/null
AOSP_ROOT="$missing_source" OUT_DIR="$missing_out" ARTIFACT_ROOT="$missing_artifacts" \
  scripts/aosp-build.sh --dry-run >/dev/null
ANDROID_SDK_ROOT="$sandbox/missing-sdk" ANDROID_AVD_HOME="$sandbox/missing-avd" ARTIFACT_ROOT="$missing_artifacts" \
  scripts/sdk-emulator-smoke.sh --dry-run >/dev/null
AOSP_ROOT="$missing_source" OUT_DIR="$missing_out" ANDROID_SDK_ROOT="$sandbox/missing-sdk" ARTIFACT_ROOT="$missing_artifacts" \
  scripts/cuttlefish-smoke.sh --dry-run >/dev/null
INSTANCE_NUM=2 scripts/cuttlefish-smoke.sh --dry-run >"$sandbox/cvd-instance-2.txt"
grep -Fq '127.0.0.1:6521' "$sandbox/cvd-instance-2.txt"
if INSTANCE_NUM=2 ANDROID_SERIAL=127.0.0.1:6520 scripts/cuttlefish-smoke.sh --dry-run >/dev/null 2>&1; then
  printf 'Cuttlefish accepted a serial that does not match its instance\n' >&2
  exit 1
fi
if LUNCH_TARGET=aosp_cf_x86_64_only_phone-aosp_current-userdebug-bad scripts/aosp-build.sh --dry-run >/dev/null 2>&1; then
  printf 'build accepted an unreviewed lunch target override\n' >&2
  exit 1
fi
TELEGRAM_CONFIG="$sandbox/missing-telegram.conf" scripts/telegram-notify.sh --test --dry-run >/dev/null

for path in "$missing_source" "$missing_out" "$missing_artifacts"; do
  [[ ! -e "$path" ]] || { printf 'dry-run unexpectedly created %s\n' "$path" >&2; exit 1; }
done

# Safety invariants: no unqualified adb shell/control command in executable
# entry points, no broad process killing, no AOSP clean/clobber, no push/publish.
if grep -RInE '(^|[[:space:]])adb[[:space:]]+(shell|exec-out|logcat|bugreport|emu|wait-for-device)' scripts --include='*.sh'; then
  printf 'found an unqualified adb control command\n' >&2
  exit 1
fi
if grep -RInE '(^|[[:space:]])(pkill|killall)[[:space:]]|m[[:space:]]+(clean|clobber)|repo[[:space:]]+forall.*reset|git[[:space:]]+push' scripts --include='*.sh'; then
  printf 'found a forbidden broad/destructive/publish operation\n' >&2
  exit 1
fi
mapfile -t telegram_api_files < <(grep -RIl 'api\.telegram\.org' scripts --include='*.sh' || true)
[[ ${#telegram_api_files[@]} -eq 1 && "${telegram_api_files[0]}" == scripts/lib/telegram.sh ]] || {
  printf 'Telegram API endpoint must exist only in scripts/lib/telegram.sh\n' >&2
  printf '  %s\n' "${telegram_api_files[@]:-none}" >&2
  exit 1
}

# License acceptance must remain behind the exact explicit assertion.
grep -Fq 'ACCEPT_ANDROID_SDK_LICENSES=I_HAVE_AUTHORITY_TO_ACCEPT' scripts/sdk-emulator-smoke.sh
grep -Fq 'INSTALL_MISSING_SDK_PACKAGES' scripts/sdk-emulator-smoke.sh
grep -Fq -- '--no-use-superproject' scripts/aosp-init-sync.sh
grep -Fq 'display_size=' scripts/lib/common.sh
grep -Fq 'package="com.android.systemui"' scripts/lib/common.sh
grep -Fq 'socket.SO_REUSEADDR' scripts/cuttlefish-smoke.sh
for signal_script in scripts/aosp-init-sync.sh scripts/aosp-build.sh; do
  grep -Fq "trap 'exit 130' INT" "$signal_script"
  grep -Fq "trap 'exit 143' TERM" "$signal_script"
done

# Exercise Telegram config parsing without network or a real credential.
# shellcheck source=../scripts/lib/telegram.sh
source scripts/lib/telegram.sh
telegram_config="$sandbox/telegram.conf"
synthetic_token='12345:'"ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcd"
printf 'BOT_TOKEN=%s\nCHAT_ID=123456789\n' "$synthetic_token" >"$telegram_config"
chmod 0600 "$telegram_config"
# Loading must remove an inherited export attribute before assigning the secret.
export TELEGRAM_BOT_TOKEN=preexisting-exported-value
telegram_load_config "$telegram_config"
[[ "$TELEGRAM_CHAT_ID" == 123456789 ]]
# The token-bearing Bot API URL must be provided over stdin, never curl argv or env.
fake_bin="$sandbox/fake-bin"
mkdir "$fake_bin"
cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_CURL_ARGS"
printf '%s|%s' "${TELEGRAM_BOT_TOKEN-unset}" "${token-unset}" >"$FAKE_CURL_ENV"
cat >"$FAKE_CURL_STDIN"
for argument in "$@"; do
  case "$argument" in
    photo=@*)
      photo_spec=${argument#photo=@}
      photo_path=${photo_spec%%;*}
      od -An -tx1 -N8 -- "$photo_path" | tr -d '[:space:]' >"$FAKE_PHOTO_MAGIC"
      ;;
  esac
done
printf '{"ok":true,"result":{"message_id":1}}'
EOF
chmod 0700 "$fake_bin/curl"
export token=preexisting-exported-lowercase-value
FAKE_CURL_ARGS="$sandbox/curl.args" FAKE_CURL_STDIN="$sandbox/curl.stdin" \
FAKE_CURL_ENV="$sandbox/curl.env" FAKE_PHOTO_MAGIC="$sandbox/photo.magic" \
  PATH="$fake_bin:$PATH" telegram_api "$TELEGRAM_BOT_TOKEN" getMe --request POST >/dev/null
assert_not_contains "$synthetic_token" "$sandbox/curl.args"
[[ $(<"$sandbox/curl.env") == 'unset|unset' ]]
grep -Fq -- '--disable' "$sandbox/curl.args"
grep -Fq -- '--config' "$sandbox/curl.args"
grep -Fq -- '--retry' "$sandbox/curl.args"
grep -Fq "$synthetic_token" "$sandbox/curl.stdin"
FAKE_CURL_ARGS="$sandbox/send.args" FAKE_CURL_STDIN="$sandbox/send.stdin" \
FAKE_CURL_ENV="$sandbox/send.env" FAKE_PHOTO_MAGIC="$sandbox/send-photo.magic" \
  PATH="$fake_bin:$PATH" telegram_api "$TELEGRAM_BOT_TOKEN" sendMessage --request POST >/dev/null
assert_not_contains '--retry' "$sandbox/send.args"

negative_config="$sandbox/negative-chat.conf"
printf 'BOT_TOKEN=%s\nCHAT_ID=-100123456789\n' "$synthetic_token" >"$negative_config"
chmod 0600 "$negative_config"
if telegram_load_config "$negative_config" 2>/dev/null; then
  printf 'negative non-private Telegram chat ID was accepted\n' >&2
  exit 1
fi
chmod 0644 "$telegram_config"
if telegram_load_config "$telegram_config" 2>/dev/null; then
  printf 'insecure Telegram config permissions were accepted\n' >&2
  exit 1
fi
chmod 0600 "$telegram_config"
shared_config_dir="$sandbox/shared-config"
mkdir -m 0777 "$shared_config_dir"
printf 'BOT_TOKEN=%s\nCHAT_ID=123456789\n' "$synthetic_token" >"$shared_config_dir/telegram.conf"
chmod 0600 "$shared_config_dir/telegram.conf"
if telegram_load_config "$shared_config_dir/telegram.conf" 2>/dev/null; then
  printf 'Telegram config in a writable parent was accepted\n' >&2
  exit 1
fi

# Exercise evidence validators with synthetic inputs.
# shellcheck source=../scripts/lib/common.sh
source scripts/lib/common.sh
alias_root="$sandbox/aosp-root"
alias_storage="$sandbox/aosp-output"
mkdir "$alias_root"
prepare_aosp_out_alias "$alias_root" "$alias_storage" out-fluent
[[ -L "$alias_root/out-fluent" ]]
[[ $(readlink -f "$alias_root/out-fluent") == "$(readlink -f "$alias_storage")" ]]
# Idempotent reuse must not replace or reject the validated alias.
prepare_aosp_out_alias "$alias_root" "$alias_storage" out-fluent
python3 - "$sandbox/valid.png" <<'PY'
import struct
import sys
path = sys.argv[1]
# The smoke validator intentionally performs structural, not full decoder, validation.
header = b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 1080, 2400)
with open(path, "wb") as stream:
    stream.write(header)
    stream.write(b"x" * 12_000)
PY
chmod 0644 "$sandbox/valid.png"
validate_png "$sandbox/valid.png" >/dev/null

# The entry point must suppress xtrace, keep the token out of child env/argv,
# validate image content, and upload through its pinned file descriptor.
FAKE_CURL_ARGS="$sandbox/notify.args" FAKE_CURL_STDIN="$sandbox/notify.stdin" \
FAKE_CURL_ENV="$sandbox/notify.env" FAKE_PHOTO_MAGIC="$sandbox/notify-photo.magic" \
PATH="$fake_bin:$PATH" bash -x scripts/telegram-notify.sh \
  --config "$telegram_config" --title 'Synthetic test' --message 'No network' \
  --photo "$sandbox/valid.png" >"$sandbox/notify.stdout" 2>"$sandbox/notify.trace"
assert_not_contains "$synthetic_token" "$sandbox/notify.trace"
assert_not_contains "$synthetic_token" "$sandbox/notify.args"
[[ $(<"$sandbox/notify.env") == 'unset|unset' ]]
[[ $(<"$sandbox/notify-photo.magic") == 89504e470d0a1a0a ]]
assert_not_contains '--retry' "$sandbox/notify.args"
printf 'not really an image\n' >"$sandbox/invalid.png"
if scripts/telegram-notify.sh --dry-run --title test --photo "$sandbox/invalid.png" >/dev/null 2>&1; then
  printf 'invalid image content was accepted\n' >&2
  exit 1
fi
cp "$sandbox/valid.png" "$shared_config_dir/shared.png"
chmod 0644 "$shared_config_dir/shared.png"
if scripts/telegram-notify.sh --dry-run --title test --photo "$shared_config_dir/shared.png" >/dev/null 2>&1; then
  printf 'photo in a writable parent was accepted\n' >&2
  exit 1
fi

printf '%s\n' 'ordinary log line' >"$sandbox/clean.log"
scan_target_failures "$sandbox/clean.log" "$sandbox/clean-signals.txt" 'com.android.systemui,com.android.settings'
cat >"$sandbox/crash.log" <<'EOF'
08-11 00:00:00.000  1000  1000 E AndroidRuntime: FATAL EXCEPTION: main
08-11 00:00:00.001  1000  1000 E AndroidRuntime: Process: com.android.systemui, PID: 1000
08-11 00:00:00.002  1000  1000 E AndroidRuntime: java.lang.IllegalStateException: fixture
EOF
if scan_target_failures "$sandbox/crash.log" "$sandbox/crash-signals.txt" 'com.android.systemui,com.android.settings'; then
  printf 'crash fixture was not detected\n' >&2
  exit 1
fi
grep -Fq 'com.android.systemui' "$sandbox/crash-signals.txt"
printf '%s\n' '08-11 00:00:01.000  1000  1000 E ActivityManager: ANR in com.android.settings (com.android.settings/.Settings)' >"$sandbox/anr.log"
if scan_target_failures "$sandbox/anr.log" "$sandbox/anr-signals.txt" 'com.android.systemui,com.android.settings'; then
  printf 'ANR fixture was not detected\n' >&2
  exit 1
fi
printf '%s\n' '08-11 00:00:02.000  1000  1000 F libc: Fatal signal 6 (SIGABRT) in tid 1000 (systemui), pid 1000 (com.android.systemui)' >"$sandbox/native-crash.log"
if scan_target_failures "$sandbox/native-crash.log" "$sandbox/native-signals.txt" 'com.android.systemui,com.android.settings'; then
  printf 'native fatal-signal fixture was not detected\n' >&2
  exit 1
fi

printf 'Validated %d shell files, %d help modes, six non-mutating dry-runs plus rejection cases, Telegram secret controls, static safety invariants, PNG validation, and Java/ANR/native crash classification.\n' \
  "${#scripts[@]}" "${#entrypoints[@]}"
