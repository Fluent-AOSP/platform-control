#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/sdk-emulator-smoke.sh [--dry-run] [--install-missing] [--help]

Boot the dedicated AOSP SDK AVD headlessly, capture home/Quick Settings evidence,
scan SystemUI/Settings crash and ANR signals, and stop only the owned emulator.

Environment:
  ANDROID_SDK_ROOT       Default: /opt/android-sdk
  ANDROID_AVD_HOME       Default: /mnt/android-avd
  AVD_NAME               Default: aosp-bootstrap-api36
  SDK_IMAGE_PACKAGE      Default: system-images;android-36;default;x86_64
  EMULATOR_PORT          Even console port (default: 5554)
  ARTIFACT_ROOT          Default: /home/azureuser/android-test-artifacts
  ADB_TIMEOUT            Default: 240 seconds
  BOOT_TIMEOUT           Default: 420 seconds
  PACKAGE_TIMEOUT        Default: 90 seconds
  BUGREPORT_TIMEOUT      Default: 300 seconds
  STOP_TIMEOUT           Default: 30 seconds
  WIPE_DATA              1 resets the dedicated AVD (default: 1)
  COLLECT_BUGREPORT      0 disables bugreport collection (default: 1)
  TARGET_PACKAGES        CSV; default: com.android.systemui,com.android.settings
  EXPECTED_EMULATOR_VERSION  Default: 37.1.11
  EXPECTED_PLATFORM_TOOLS    Default: 37.0.1
  EXPECTED_IMAGE_REVISION    Default: 2
  ALLOW_SDK_VERSION_MISMATCH 1 permits a reviewed version difference

Package/license boundary:
  Default operation never installs SDK packages or accepts terms. --install-missing
  additionally requires INSTALL_MISSING_SDK_PACKAGES=1 and the explicit legal-
  authority assertion below. It runs sdkmanager --licenses before installation:

  ACCEPT_ANDROID_SDK_LICENSES=I_HAVE_AUTHORITY_TO_ACCEPT

That command can present/accept multiple SDK agreements. Automation is not legal
authority. Review the terms before setting the assertion.

Dry-run performs no launch, installation, reset, or artifact write.
EOF
}

DRY_RUN=0
INSTALL_MISSING=0
for argument in "$@"; do
  case "$argument" in
    --dry-run) DRY_RUN=1 ;;
    --install-missing) INSTALL_MISSING=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown argument: $argument" ;;
  esac
done

ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-/opt/android-sdk}
ANDROID_AVD_HOME=${ANDROID_AVD_HOME:-/mnt/android-avd}
AVD_NAME=${AVD_NAME:-aosp-bootstrap-api36}
SDK_IMAGE_PACKAGE=${SDK_IMAGE_PACKAGE:-system-images;android-36;default;x86_64}
EMULATOR_PORT=${EMULATOR_PORT:-5554}
ARTIFACT_ROOT=${ARTIFACT_ROOT:-/home/azureuser/android-test-artifacts}
ADB_TIMEOUT=${ADB_TIMEOUT:-240}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-420}
PACKAGE_TIMEOUT=${PACKAGE_TIMEOUT:-90}
BUGREPORT_TIMEOUT=${BUGREPORT_TIMEOUT:-300}
STOP_TIMEOUT=${STOP_TIMEOUT:-30}
WIPE_DATA=${WIPE_DATA:-1}
COLLECT_BUGREPORT=${COLLECT_BUGREPORT:-1}
TARGET_PACKAGES=${TARGET_PACKAGES:-com.android.systemui,com.android.settings}
EXPECTED_EMULATOR_VERSION=${EXPECTED_EMULATOR_VERSION:-37.1.11}
EXPECTED_PLATFORM_TOOLS=${EXPECTED_PLATFORM_TOOLS:-37.0.1}
EXPECTED_IMAGE_REVISION=${EXPECTED_IMAGE_REVISION:-2}
ALLOW_SDK_VERSION_MISMATCH=${ALLOW_SDK_VERSION_MISMATCH:-0}

for item in "ADB_TIMEOUT:$ADB_TIMEOUT" "BOOT_TIMEOUT:$BOOT_TIMEOUT" "PACKAGE_TIMEOUT:$PACKAGE_TIMEOUT" \
  "BUGREPORT_TIMEOUT:$BUGREPORT_TIMEOUT" "STOP_TIMEOUT:$STOP_TIMEOUT"; do
  require_positive_integer "${item%%:*}" "${item#*:}"
done
require_positive_integer EMULATOR_PORT "$EMULATOR_PORT"
(( EMULATOR_PORT % 2 == 0 )) || die 'EMULATOR_PORT must be even'
(( EMULATOR_PORT >= 5554 && EMULATOR_PORT <= 5682 )) || die 'EMULATOR_PORT must be in the Android Emulator console range 5554..5682'
[[ "$WIPE_DATA" == 0 || "$WIPE_DATA" == 1 ]] || die 'WIPE_DATA must be 0 or 1'
[[ "$COLLECT_BUGREPORT" == 0 || "$COLLECT_BUGREPORT" == 1 ]] || die 'COLLECT_BUGREPORT must be 0 or 1'
[[ "$ALLOW_SDK_VERSION_MISMATCH" == 0 || "$ALLOW_SDK_VERSION_MISMATCH" == 1 ]] || die 'ALLOW_SDK_VERSION_MISMATCH must be 0 or 1'
serial="emulator-$EMULATOR_PORT"

if [[ "$DRY_RUN" == 1 ]]; then
  printf 'DRY-RUN: SDK=%q AVD_HOME=%q AVD=%q SERIAL=%q\n' "$ANDROID_SDK_ROOT" "$ANDROID_AVD_HOME" "$AVD_NAME" "$serial"
  if [[ "$INSTALL_MISSING" == 1 ]]; then
    printf 'DRY-RUN: require INSTALL_MISSING_SDK_PACKAGES=1 and ACCEPT_ANDROID_SDK_LICENSES=I_HAVE_AUTHORITY_TO_ACCEPT\n'
    printf 'DRY-RUN: sdkmanager --licenses, then install platform-tools/emulator/%q\n' "$SDK_IMAGE_PACKAGE"
  fi
  printf 'DRY-RUN: acquire per-AVD and console-port locks; reject an existing transport/listener; launch named AVD with KVM/SwiftShader and bounded stages\n'
  printf 'DRY-RUN: target every adb control command with -s %q; capture/validate evidence; stop owned PID\n' "$serial"
  exit 0
fi

sdkmanager_bin="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
adb_bin="$ANDROID_SDK_ROOT/platform-tools/adb"
emulator_bin="$ANDROID_SDK_ROOT/emulator/emulator"
image_dir="$ANDROID_SDK_ROOT/${SDK_IMAGE_PACKAGE//;/\/}"

missing=0
[[ -x "$adb_bin" ]] || missing=1
[[ -x "$emulator_bin" ]] || missing=1
[[ -f "$image_dir/source.properties" ]] || missing=1
if (( missing )); then
  [[ "$INSTALL_MISSING" == 1 && "${INSTALL_MISSING_SDK_PACKAGES:-0}" == 1 ]] \
    || die 'SDK packages are missing; installation is opt-in via --install-missing and INSTALL_MISSING_SDK_PACKAGES=1'
  [[ "${ACCEPT_ANDROID_SDK_LICENSES:-}" == I_HAVE_AUTHORITY_TO_ACCEPT ]] \
    || die 'license acceptance not authorized; review terms and set ACCEPT_ANDROID_SDK_LICENSES=I_HAVE_AUTHORITY_TO_ACCEPT'
  [[ -x "$sdkmanager_bin" ]] || die "sdkmanager not found: $sdkmanager_bin"
  set +o pipefail
  yes | "$sdkmanager_bin" --sdk_root="$ANDROID_SDK_ROOT" --licenses
  license_status=${PIPESTATUS[1]}
  set -o pipefail
  (( license_status == 0 )) || die 'sdkmanager license acceptance failed'
  "$sdkmanager_bin" --sdk_root="$ANDROID_SDK_ROOT" --install platform-tools emulator "$SDK_IMAGE_PACKAGE"
fi

require_file "$ANDROID_AVD_HOME/$AVD_NAME.ini"
[[ -d "$ANDROID_AVD_HOME/$AVD_NAME.avd" ]] || die "AVD directory not found: $ANDROID_AVD_HOME/$AVD_NAME.avd"

read_property() { awk -F= -v key="$2" '$1 == key {print $2}' "$1" | tail -1 | tr -d '\r'; }
emulator_version=$(read_property "$ANDROID_SDK_ROOT/emulator/source.properties" Pkg.Revision)
platform_tools_version=$(read_property "$ANDROID_SDK_ROOT/platform-tools/source.properties" Pkg.Revision)
image_revision=$(read_property "$image_dir/source.properties" Pkg.Revision)
for observed_expected in \
  "emulator:$emulator_version:$EXPECTED_EMULATOR_VERSION" \
  "platform-tools:$platform_tools_version:$EXPECTED_PLATFORM_TOOLS" \
  "system-image:$image_revision:$EXPECTED_IMAGE_REVISION"; do
  IFS=: read -r label observed expected <<<"$observed_expected"
  if [[ "$observed" != "$expected" ]]; then
    [[ "$ALLOW_SDK_VERSION_MISMATCH" == 1 ]] || die "$label version mismatch: expected $expected, observed $observed"
    warn "allowing reviewed $label version mismatch: expected $expected, observed $observed"
  fi
done

export ANDROID_SDK_ROOT ANDROID_AVD_HOME
install -d -m 0750 "$ARTIFACT_ROOT"
exec {lock_fd}>"$ARTIFACT_ROOT/.${AVD_NAME}.lock"
flock -n "$lock_fd" || die "another run owns AVD lock: $AVD_NAME"
exec {port_lock_fd}>"$ARTIFACT_ROOT/.emulator-port-${EMULATOR_PORT}.lock"
flock -n "$port_lock_fd" || die "another run owns emulator port lock: $EMULATOR_PORT"
run_dir=$(new_run_dir "$ARTIFACT_ROOT" sdk-emulator)
emulator_pid=
logcat_pid=
transport_owned=0
verification_complete=0

stop_owned_emulator() {
  local graceful=0 deadline
  [[ -n "${emulator_pid:-}" ]] || return 0
  if ! kill -0 "$emulator_pid" 2>/dev/null; then
    wait "$emulator_pid" 2>/dev/null || true
    emulator_pid=
    return 1
  fi
  if [[ "$transport_owned" == 1 ]] && timeout "$STOP_TIMEOUT" "$adb_bin" -s "$serial" emu kill \
      >"$run_dir/emulator-stop.txt" 2>&1; then
    graceful=1
  else
    printf 'graceful console stop unavailable or failed\n' >>"$run_dir/emulator-stop.txt"
  fi
  deadline=$((SECONDS + STOP_TIMEOUT))
  while kill -0 "$emulator_pid" 2>/dev/null && (( SECONDS < deadline )); do sleep 1; done
  if kill -0 "$emulator_pid" 2>/dev/null; then
    graceful=0
    kill -TERM "$emulator_pid" 2>/dev/null || true
    printf 'graceful stop timed out; sent TERM to owned PID\n' >>"$run_dir/emulator-stop.txt"
    deadline=$((SECONDS + STOP_TIMEOUT))
    while kill -0 "$emulator_pid" 2>/dev/null && (( SECONDS < deadline )); do sleep 1; done
  fi
  if kill -0 "$emulator_pid" 2>/dev/null; then
    kill -KILL "$emulator_pid" 2>/dev/null || true
    printf 'TERM timed out; sent KILL to owned PID\n' >>"$run_dir/emulator-stop.txt"
    graceful=0
  fi
  wait "$emulator_pid" 2>/dev/null || true
  emulator_pid=
  (( graceful == 1 ))
}

cleanup() {
  local status=$? stop_status=0 success_photo=
  trap - EXIT INT TERM
  set +e
  if [[ -n "${logcat_pid:-}" ]]; then kill "$logcat_pid" 2>/dev/null; wait "$logcat_pid" 2>/dev/null; logcat_pid=; fi
  if [[ -n "${emulator_pid:-}" ]]; then
    stop_owned_emulator
    stop_status=$?
  fi
  if (( status == 0 )) && [[ "$verification_complete" != 1 || "$transport_owned" != 1 ]]; then status=1; fi
  if (( status == 0 && stop_status != 0 )); then status=1; fi
  if (( status == 0 )); then
    printf 'PASS\n' >"$run_dir/result.txt"
    [[ "$WIPE_DATA" == 1 ]] && success_photo="$run_dir/quick-settings.png"
    notify_telegram_safe success 'SDK Emulator smoke passed' \
      "A test-owned AOSP SDK instance passed boot, Quick Settings, evidence, crash/ANR, and clean-stop gates. Evidence: $run_dir" \
      "$success_photo"
    log "SDK Emulator smoke passed; evidence: $run_dir"
  else
    printf 'FAIL exit=%d stop_exit=%d\n' "$status" "$stop_status" >"$run_dir/result.txt"
    notify_telegram_safe failure 'SDK Emulator smoke failed' \
      "The unattended bootstrap loop exited with status $status. Evidence: $run_dir"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$adb_bin" start-server >"$run_dir/adb-start.txt" 2>&1
if "$adb_bin" devices | awk -v serial="$serial" '$1 == serial {found=1} END {exit !found}'; then
  die "ADB transport already exists before launch: $serial"
fi
python3 - "$EMULATOR_PORT" <<'PY'
import socket
import sys

for port in (int(sys.argv[1]), int(sys.argv[1]) + 1):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(("127.0.0.1", port))
    except OSError as exc:
        raise SystemExit(f"emulator port is already in use: {port}: {exc}")
    finally:
        sock.close()
PY
"$emulator_bin" -accel-check >"$run_dir/accel-check.txt" 2>&1
"$emulator_bin" -list-avds | grep -Fx "$AVD_NAME" >"$run_dir/avd-selected.txt" \
  || die "AVD not listed by emulator: $AVD_NAME"

launch_args=("@$AVD_NAME" -port "$EMULATOR_PORT" -no-window -no-audio -no-boot-anim -no-snapshot -no-metrics -accel on -gpu swiftshader_indirect -memory 4096 -cores 4)
[[ "$WIPE_DATA" == 0 ]] || launch_args+=(-wipe-data)
"$emulator_bin" "${launch_args[@]}" </dev/null >"$run_dir/emulator.stdout.log" 2>&1 &
emulator_pid=$!
printf '%s\n' "$emulator_pid" >"$run_dir/emulator.pid"

transport_deadline=$((SECONDS + ADB_TIMEOUT))
while (( SECONDS < transport_deadline )); do
  kill -0 "$emulator_pid" 2>/dev/null || die 'owned emulator exited before publishing its ADB transport'
  if [[ "$("$adb_bin" -s "$serial" get-state 2>/dev/null || true)" == device ]]; then break; fi
  sleep 1
done
[[ "$("$adb_bin" -s "$serial" get-state 2>/dev/null || true)" == device ]] || die 'ADB transport deadline exceeded'
kill -0 "$emulator_pid" 2>/dev/null || die 'owned emulator exited after ADB transport appeared'
"$adb_bin" -s "$serial" emu avd name >"$run_dir/emulator-avd-name.txt" 2>&1
[[ "$(head -1 "$run_dir/emulator-avd-name.txt" | tr -d '\r')" == "$AVD_NAME" ]] \
  || die 'ADB transport does not report the launched AVD name'
transport_owned=1
wait_for_boot_complete "$adb_bin" "$serial" "$BOOT_TIMEOUT" || die 'sys.boot_completed deadline exceeded'
wait_for_package_manager "$adb_bin" "$serial" "$PACKAGE_TIMEOUT" || die 'package-manager deadline exceeded'

record_provenance "$adb_bin" "$serial" "$run_dir/provenance.txt" sdk-emulator
{
  printf 'avd_name=%s\n' "$AVD_NAME"
  printf 'sdk_image_package=%s\n' "$SDK_IMAGE_PACKAGE"
  printf 'emulator_version=%s\n' "$emulator_version"
  printf 'platform_tools_version=%s\n' "$platform_tools_version"
  printf 'image_revision=%s\n' "$image_revision"
  printf 'wipe_data=%s\n' "$WIPE_DATA"
} >>"$run_dir/provenance.txt"

"$adb_bin" -s "$serial" logcat -b all -d -v threadtime >"$run_dir/startup-logcat.txt" 2>&1
"$adb_bin" -s "$serial" logcat -c
"$adb_bin" -s "$serial" logcat -b all -v threadtime >"$run_dir/logcat.txt" 2>&1 &
logcat_pid=$!
capture_ui_smoke "$adb_bin" "$serial" "$run_dir"
collect_standard_evidence "$adb_bin" "$serial" "$run_dir" "$BUGREPORT_TIMEOUT"
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
