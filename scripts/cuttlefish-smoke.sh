#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/cuttlefish-smoke.sh [--dry-run] [--help]

Boot locally built AOSP images with host tools from the same OUT_DIR, collect UI
and failure evidence through one explicit ADB serial, and stop the owned instance.

Environment:
  AOSP_ROOT          Default: /mnt/aosp
  OUT_DIR            Default: /home/azureuser/aosp-out
  LUNCH_TARGET       Default/approved: aosp_cf_x86_64_only_phone-aosp_current-userdebug
  ALLOW_LUNCH_TARGET_OVERRIDE  1 permits a reviewed target override
  ANDROID_SDK_ROOT   Used for adb fallback (default: /opt/android-sdk)
  ANDROID_SERIAL     Must match this instance's derived port (default: 127.0.0.1:6520)
  INSTANCE_NUM       Default: 1; ADB port is 6520 + INSTANCE_NUM - 1
  ARTIFACT_ROOT      Default: /home/azureuser/android-test-artifacts
  ADB_TIMEOUT        Default: 240 seconds
  BOOT_TIMEOUT       Default: 420 seconds
  PACKAGE_TIMEOUT    Default: 90 seconds
  CVD_LAUNCH_TIMEOUT Default: 180 seconds
  BUGREPORT_TIMEOUT  Default: 300 seconds
  STOP_TIMEOUT       Default: 60 seconds
  COLLECT_BUGREPORT  0 disables bugreport collection (default: 1)
  TARGET_PACKAGES    CSV; default: com.android.systemui,com.android.settings
  FIRST_FEEDBACK_MARKER  Default: ~/.local/state/fluent-aosp/first-cuttlefish-feedback.sent

Dry-run does not source AOSP, launch a device, or create artifacts. This script
never downloads/mixes prebuilt Cuttlefish images or host packages.
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
OUT_DIR=${OUT_DIR:-/home/azureuser/aosp-out}
APPROVED_LUNCH_TARGET=aosp_cf_x86_64_only_phone-aosp_current-userdebug
LUNCH_TARGET=${LUNCH_TARGET:-$APPROVED_LUNCH_TARGET}
ALLOW_LUNCH_TARGET_OVERRIDE=${ALLOW_LUNCH_TARGET_OVERRIDE:-0}
ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-/opt/android-sdk}
INSTANCE_NUM=${INSTANCE_NUM:-1}
ARTIFACT_ROOT=${ARTIFACT_ROOT:-/home/azureuser/android-test-artifacts}
ADB_TIMEOUT=${ADB_TIMEOUT:-240}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-420}
PACKAGE_TIMEOUT=${PACKAGE_TIMEOUT:-90}
CVD_LAUNCH_TIMEOUT=${CVD_LAUNCH_TIMEOUT:-180}
BUGREPORT_TIMEOUT=${BUGREPORT_TIMEOUT:-300}
STOP_TIMEOUT=${STOP_TIMEOUT:-60}
COLLECT_BUGREPORT=${COLLECT_BUGREPORT:-1}
TARGET_PACKAGES=${TARGET_PACKAGES:-com.android.systemui,com.android.settings}
FIRST_FEEDBACK_MARKER=${FIRST_FEEDBACK_MARKER:-${XDG_STATE_HOME:-$HOME/.local/state}/fluent-aosp/first-cuttlefish-feedback.sent}

for item in "INSTANCE_NUM:$INSTANCE_NUM" "ADB_TIMEOUT:$ADB_TIMEOUT" "BOOT_TIMEOUT:$BOOT_TIMEOUT" \
  "PACKAGE_TIMEOUT:$PACKAGE_TIMEOUT" "CVD_LAUNCH_TIMEOUT:$CVD_LAUNCH_TIMEOUT" \
  "BUGREPORT_TIMEOUT:$BUGREPORT_TIMEOUT" "STOP_TIMEOUT:$STOP_TIMEOUT"; do
  require_positive_integer "${item%%:*}" "${item#*:}"
done
[[ "$COLLECT_BUGREPORT" == 0 || "$COLLECT_BUGREPORT" == 1 ]] || die 'COLLECT_BUGREPORT must be 0 or 1'
[[ "$ALLOW_LUNCH_TARGET_OVERRIDE" == 0 || "$ALLOW_LUNCH_TARGET_OVERRIDE" == 1 ]] || die 'ALLOW_LUNCH_TARGET_OVERRIDE must be 0 or 1'
if [[ "$LUNCH_TARGET" != "$APPROVED_LUNCH_TARGET" ]]; then
  [[ "$ALLOW_LUNCH_TARGET_OVERRIDE" == 1 ]] || die "LUNCH_TARGET must be $APPROVED_LUNCH_TARGET"
  warn "allowing reviewed lunch target override: $LUNCH_TARGET"
fi
expected_adb_port=$((6520 + INSTANCE_NUM - 1))
ANDROID_SERIAL=${ANDROID_SERIAL:-127.0.0.1:$expected_adb_port}
case "$ANDROID_SERIAL" in
  "127.0.0.1:$expected_adb_port" | "0.0.0.0:$expected_adb_port") ;;
  *) die "ANDROID_SERIAL must target Cuttlefish instance $INSTANCE_NUM on port $expected_adb_port" ;;
esac

if [[ "$DRY_RUN" == 1 ]]; then
  printf 'DRY-RUN: source %q; lunch %q with OUT_DIR=%q\n' "$AOSP_ROOT/build/envsetup.sh" "$LUNCH_TARGET" "$OUT_DIR"
  printf 'DRY-RUN: require same-build ANDROID_PRODUCT_OUT images and ANDROID_HOST_OUT/bin/launch_cvd\n'
  printf 'DRY-RUN: acquire instance lock; launch with unique HOME, --daemon, --report_anonymous_usage_stats=n'
  [[ "$INSTANCE_NUM" == 1 ]] || printf ', --base_instance_num=%q' "$INSTANCE_NUM"
  printf '\nDRY-RUN: connect/wait only for adb serial %q; capture/validate evidence; stop through same-build tool and unique HOME\n' "$ANDROID_SERIAL"
  exit 0
fi

require_file "$AOSP_ROOT/build/envsetup.sh"
require_dir "$AOSP_ROOT/.repo"
install -d -m 0750 "$OUT_DIR" "$ARTIFACT_ROOT"
export OUT_DIR

# Resolve output paths and functions from the selected build in this shell.
cd "$AOSP_ROOT"
set +u
# shellcheck disable=SC1091
source build/envsetup.sh
set -u
lunch "$LUNCH_TARGET"

[[ "${TARGET_PRODUCT:-}" == aosp_cf_x86_64_only_phone ]] || die "lunch resolved unexpected product: ${TARGET_PRODUCT:-unset}"
[[ -n "${ANDROID_PRODUCT_OUT:-}" && -d "$ANDROID_PRODUCT_OUT" ]] || die 'ANDROID_PRODUCT_OUT is missing; build the target first'
[[ -n "${ANDROID_HOST_OUT:-}" && -d "$ANDROID_HOST_OUT" ]] || die 'ANDROID_HOST_OUT is missing; build the target first'
launch_cvd_bin="$ANDROID_HOST_OUT/bin/launch_cvd"
stop_cvd_bin="$ANDROID_HOST_OUT/bin/stop_cvd"
[[ -x "$launch_cvd_bin" ]] || die "same-build launch_cvd not executable: $launch_cvd_bin"
[[ -x "$stop_cvd_bin" ]] || die "same-build stop_cvd not executable: $stop_cvd_bin"

adb_bin="$ANDROID_HOST_OUT/bin/adb"
[[ -x "$adb_bin" ]] || adb_bin="$ANDROID_SDK_ROOT/platform-tools/adb"
[[ -x "$adb_bin" ]] || die 'adb not found in same-build host output or Android SDK'

# Require representative product artifacts without assuming every partition layout.
find "$ANDROID_PRODUCT_OUT" -maxdepth 1 -type f -name 'system.img' -print -quit | grep -q . \
  || die "system.img not found in $ANDROID_PRODUCT_OUT"

exec {lock_fd}>"$ARTIFACT_ROOT/.cuttlefish-instance-${INSTANCE_NUM}.lock"
flock -n "$lock_fd" || die "another run owns Cuttlefish instance lock: $INSTANCE_NUM"
exec {port_lock_fd}>"$ARTIFACT_ROOT/.cuttlefish-adb-port-${expected_adb_port}.lock"
flock -n "$port_lock_fd" || die "another run owns Cuttlefish ADB port lock: $expected_adb_port"
run_dir=$(new_run_dir "$ARTIFACT_ROOT" cuttlefish)
cvd_home="$run_dir/cvd-home"
install -d -m 0750 "$cvd_home"
logcat_pid=
launched=0
transport_owned=0
verification_complete=0

cuttlefish_port_is_free() {
  python3 - "$expected_adb_port" <<'PY'
import socket
import sys

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    sock.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    raise SystemExit(1)
finally:
    sock.close()
PY
}

stop_owned_cuttlefish() {
  local stop_status=0 deadline
  [[ "$launched" == 1 ]] || return 0
  if timeout "$STOP_TIMEOUT" env HOME="$cvd_home" "$stop_cvd_bin" \
      >"$run_dir/cuttlefish-stop.txt" 2>&1; then
    stop_status=0
  else
    stop_status=$?
    printf 'same-build stop_cvd failed or timed out with status %s; no unrelated processes were targeted\n' \
      "$stop_status" >>"$run_dir/cuttlefish-stop.txt"
  fi
  deadline=$((SECONDS + STOP_TIMEOUT))
  while (( SECONDS < deadline )); do
    if cuttlefish_port_is_free; then break; fi
    sleep 1
  done
  if ! cuttlefish_port_is_free; then
    printf 'owned Cuttlefish ADB port remained in use after stop\n' >>"$run_dir/cuttlefish-stop.txt"
    stop_status=1
  fi
  launched=0
  (( stop_status == 0 ))
}

cleanup() {
  local status=$? stop_status=0 marker_dir marker_tmp
  trap - EXIT INT TERM
  set +e
  if [[ -n "${logcat_pid:-}" ]]; then kill "$logcat_pid" 2>/dev/null; wait "$logcat_pid" 2>/dev/null; logcat_pid=; fi
  if [[ "$launched" == 1 ]]; then
    stop_owned_cuttlefish
    stop_status=$?
  fi
  if (( status == 0 )) && [[ "$verification_complete" != 1 || "$transport_owned" != 1 ]]; then status=1; fi
  if (( status == 0 && stop_status != 0 )); then status=1; fi
  if (( status == 0 )); then
    printf 'PASS\n' >"$run_dir/result.txt"
    if [[ ! -e "$FIRST_FEEDBACK_MARKER" ]]; then
      notify_telegram_safe success 'Cuttlefish image verified — feedback requested' \
        "A new test-owned locally built AOSP instance passed boot, Quick Settings, evidence, crash/ANR, and clean-stop gates. Please review the attached baseline. Evidence: $run_dir" \
        "$run_dir/quick-settings.png"
      if [[ "$TELEGRAM_NOTIFY_RESULT" == sent ]]; then
        marker_dir=${FIRST_FEEDBACK_MARKER%/*}
        [[ "$marker_dir" != "$FIRST_FEEDBACK_MARKER" ]] || marker_dir=.
        install -d -m 0700 "$marker_dir"
        marker_tmp=$(mktemp "$marker_dir/.first-feedback.XXXXXX")
        printf 'sent_utc=%s\nevidence=%s\nimage_sha256=%s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$run_dir" \
          "$(sha256sum "$run_dir/quick-settings.png" | awk '{print $1}')" >"$marker_tmp"
        chmod 0600 "$marker_tmp"
        mv -f -- "$marker_tmp" "$FIRST_FEEDBACK_MARKER"
      fi
    else
      notify_telegram_safe success 'Cuttlefish image verification passed' \
        "The locally built AOSP image passed boot, evidence, crash/ANR, and clean-stop gates. Evidence: $run_dir"
    fi
    log "locally built Cuttlefish smoke passed; evidence: $run_dir"
  else
    printf 'FAIL exit=%d stop_exit=%d\n' "$status" "$stop_status" >"$run_dir/result.txt"
    notify_telegram_safe failure 'Cuttlefish image verification failed' \
      "The locally built image loop exited with status $status. Evidence: $run_dir"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

repo manifest -r -o "$run_dir/source-manifest.xml"
{
  printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'runtime=cuttlefish\n'
  printf 'aosp_root=%s\n' "$AOSP_ROOT"
  printf 'out_dir=%s\n' "$OUT_DIR"
  printf 'lunch_target=%s\n' "$LUNCH_TARGET"
  printf 'target_product=%s\n' "$TARGET_PRODUCT"
  printf 'android_product_out=%s\n' "$ANDROID_PRODUCT_OUT"
  printf 'android_host_out=%s\n' "$ANDROID_HOST_OUT"
  printf 'instance_num=%s\n' "$INSTANCE_NUM"
  printf 'serial=%s\n' "$ANDROID_SERIAL"
  printf 'launch_cvd_sha256=%s\n' "$(sha256sum "$launch_cvd_bin" | awk '{print $1}')"
} >"$run_dir/build-provenance.txt"
find "$ANDROID_PRODUCT_OUT" -maxdepth 1 -type f -name '*.img' -print0 \
  | sort -z | xargs -0 -r sha256sum >"$run_dir/product-image-checksums.sha256"

"$adb_bin" start-server >"$run_dir/adb-start.txt" 2>&1
if "$adb_bin" devices | awk -v suffix=":$expected_adb_port" '$1 ~ (suffix "$") {found=1} END {exit !found}'; then
  die "an ADB transport already uses Cuttlefish port $expected_adb_port"
fi
cuttlefish_port_is_free || die "Cuttlefish ADB port is already in use: $expected_adb_port"

launch_args=(--daemon --report_anonymous_usage_stats=n)
[[ "$INSTANCE_NUM" == 1 ]] || launch_args+=("--base_instance_num=$INSTANCE_NUM")
# Mark ownership before launch so a partial/timed-out launch still gets a scoped stop attempt.
launched=1
(
  cd "$ANDROID_PRODUCT_OUT"
  timeout "$CVD_LAUNCH_TIMEOUT" env HOME="$cvd_home" "$launch_cvd_bin" "${launch_args[@]}"
) >"$run_dir/launch-cvd.log" 2>&1

mapfile -t cvd_configs < <(find -L "$cvd_home" -type f -name cuttlefish_config.json -print 2>/dev/null | sort -u)
(( ${#cvd_configs[@]} > 0 )) || die 'launch completed without a Cuttlefish configuration under the owned HOME'
selected_cvd_config=$(python3 - "0.0.0.0:$expected_adb_port" "${cvd_configs[@]}" <<'PY'
import json
import pathlib
import sys

expected = sys.argv[1]

def values(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "adb_ip_and_port":
                yield value
            yield from values(value)
    elif isinstance(node, list):
        for value in node:
            yield from values(value)

for item in sys.argv[2:]:
    path = pathlib.Path(item)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        continue
    if expected in set(values(data)):
        print(path)
        raise SystemExit(0)
raise SystemExit(f"no owned Cuttlefish config maps ADB to {expected}")
PY
)
cp -- "$selected_cvd_config" "$run_dir/cuttlefish-config.json"
printf 'expected_adb_port=%s\nselected_cvd_config=%s\n' \
  "$expected_adb_port" "$selected_cvd_config" >>"$run_dir/build-provenance.txt"

transport_deadline=$((SECONDS + ADB_TIMEOUT))
while (( SECONDS < transport_deadline )); do
  "$adb_bin" connect "$ANDROID_SERIAL" >"$run_dir/adb-connect.txt" 2>&1 || true
  if [[ "$("$adb_bin" -s "$ANDROID_SERIAL" get-state 2>/dev/null || true)" == device ]]; then break; fi
  sleep 1
done
[[ "$("$adb_bin" -s "$ANDROID_SERIAL" get-state 2>/dev/null || true)" == device ]] || die 'ADB transport deadline exceeded'
transport_owned=1
wait_for_boot_complete "$adb_bin" "$ANDROID_SERIAL" "$BOOT_TIMEOUT" || die 'sys.boot_completed deadline exceeded'
wait_for_package_manager "$adb_bin" "$ANDROID_SERIAL" "$PACKAGE_TIMEOUT" || die 'package-manager deadline exceeded'

record_provenance "$adb_bin" "$ANDROID_SERIAL" "$run_dir/provenance.txt" cuttlefish
cat "$run_dir/build-provenance.txt" >>"$run_dir/provenance.txt"
"$adb_bin" -s "$ANDROID_SERIAL" logcat -b all -d -v threadtime >"$run_dir/startup-logcat.txt" 2>&1
"$adb_bin" -s "$ANDROID_SERIAL" logcat -c
"$adb_bin" -s "$ANDROID_SERIAL" logcat -b all -v threadtime >"$run_dir/logcat.txt" 2>&1 &
logcat_pid=$!
capture_ui_smoke "$adb_bin" "$ANDROID_SERIAL" "$run_dir"
collect_standard_evidence "$adb_bin" "$ANDROID_SERIAL" "$run_dir" "$BUGREPORT_TIMEOUT"
kill "$logcat_pid" 2>/dev/null || true
wait "$logcat_pid" 2>/dev/null || true
logcat_pid=
cat "$run_dir/startup-logcat.txt" "$run_dir/logcat.txt" >"$run_dir/classification-logcat.txt"

if scan_target_failures "$run_dir/classification-logcat.txt" "$run_dir/failure-signals.txt" "$TARGET_PACKAGES"; then
  printf 'CLEAN\n' >"$run_dir/crash-signal-status.txt"
else
  printf 'FAIL\n' >"$run_dir/crash-signal-status.txt"
  die "target-package crash/ANR signals found; see $run_dir/failure-signals.txt"
fi

verification_complete=1
