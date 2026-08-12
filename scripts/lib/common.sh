#!/usr/bin/env bash
# Shared helpers. Callers must enable: set -Eeuo pipefail

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
warn() { log "WARN: $*"; }
die() { log "ERROR: $*"; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "required directory not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "required file not found: $1"
}

require_positive_integer() {
  [[ "$2" =~ ^[1-9][0-9]*$ ]] || die "$1 must be a positive integer (got: $2)"
}

prepare_aosp_out_alias() {
  local aosp_root=$1 storage_dir=$2 alias_name=$3 alias_path expected actual
  [[ "$storage_dir" == /* ]] || die "OUT_DIR storage path must be absolute: $storage_dir"
  [[ "$alias_name" =~ ^[A-Za-z0-9._-]+$ ]] || die "AOSP_OUT_ALIAS must be one safe path component: $alias_name"
  require_dir "$aosp_root"
  install -d -m 0750 "$storage_dir"
  expected=$(readlink -f -- "$storage_dir")
  alias_path="$aosp_root/$alias_name"
  if [[ -L "$alias_path" ]]; then
    actual=$(readlink -f -- "$alias_path")
    [[ "$actual" == "$expected" ]] || die "AOSP output alias points elsewhere: $alias_path -> $actual"
  elif [[ -e "$alias_path" ]]; then
    die "AOSP output alias path exists and is not a symlink: $alias_path"
  else
    ln -s -- "$expected" "$alias_path"
  fi
}

quote_command() {
  printf 'DRY-RUN:'
  printf ' %q' "$@"
  printf '\n'
}

# TELEGRAM_NOTIFY_RESULT is an intentional caller-visible delivery receipt.
# shellcheck disable=SC2034
notify_telegram_safe() {
  local level=$1 title=$2 message=$3 photo=${4:-}
  TELEGRAM_NOTIFY_RESULT=skipped
  local mode=${NOTIFY_TELEGRAM:-auto}
  local common_dir notifier config

  case "$mode" in
    0|false|off) return 0 ;;
    1|true|on|auto) ;;
    *) warn "invalid NOTIFY_TELEGRAM=$mode; notification skipped"; return 0 ;;
  esac

  common_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  notifier=${TELEGRAM_NOTIFY_SCRIPT:-$common_dir/../telegram-notify.sh}
  config=${TELEGRAM_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/fluent-aosp/telegram.conf}
  if [[ "$mode" == auto && ! -f "$config" ]]; then
    return 0
  fi
  if [[ ! -x "$notifier" ]]; then
    warn "Telegram notifier is unavailable: $notifier"
    TELEGRAM_NOTIFY_RESULT=failed
    return 0
  fi
  if [[ -n "$photo" && ! -f "$photo" ]]; then
    warn "Telegram attachment is unavailable: $photo"
    TELEGRAM_NOTIFY_RESULT=failed
    return 0
  fi

  local args=(--config "$config" --level "$level" --title "$title" --message "$message")
  [[ -z "$photo" ]] || args+=(--photo "$photo")
  if "$notifier" "${args[@]}"; then
    TELEGRAM_NOTIFY_RESULT=sent
  else
    warn "Telegram notification failed; primary operation result is unchanged"
    TELEGRAM_NOTIFY_RESULT=failed
  fi
  return 0
}

new_run_dir() {
  local root=$1 prefix=$2 run_id candidate suffix=0
  run_id="${prefix}-$(date -u +%Y%m%dT%H%M%SZ)"
  candidate="$root/$run_id"
  while [[ -e "$candidate" ]]; do
    suffix=$((suffix + 1))
    candidate="$root/${run_id}-$suffix"
  done
  install -d -m 0750 "$candidate"
  printf '%s\n' "$candidate"
}

adb_for() {
  local adb_bin=$1 serial=$2
  shift 2
  "$adb_bin" -s "$serial" "$@"
}

wait_for_adb_transport() {
  local adb_bin=$1 serial=$2 seconds=$3
  require_positive_integer ADB_TIMEOUT "$seconds"
  timeout "$seconds" "$adb_bin" -s "$serial" wait-for-device
}

wait_for_boot_complete() {
  local adb_bin=$1 serial=$2 seconds=$3 deadline
  require_positive_integer BOOT_TIMEOUT "$seconds"
  deadline=$((SECONDS + seconds))
  while (( SECONDS < deadline )); do
    if [[ "$("$adb_bin" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_for_package_manager() {
  local adb_bin=$1 serial=$2 seconds=$3 deadline
  require_positive_integer PACKAGE_TIMEOUT "$seconds"
  deadline=$((SECONDS + seconds))
  while (( SECONDS < deadline )); do
    if "$adb_bin" -s "$serial" shell cmd package list packages >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

validate_png() {
  local png=$1
  python3 - "$png" <<'PY'
import os
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as stream:
    header = stream.read(24)
if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
    raise SystemExit(f"invalid PNG header: {path}")
width, height = struct.unpack(">II", header[16:24])
size = os.path.getsize(path)
if width < 100 or height < 100 or size < 10_000:
    raise SystemExit(f"implausible screenshot: {path}: {width}x{height}, {size} bytes")
print(f"{os.path.basename(path)}\t{width}x{height}\t{size} bytes")
PY
}

record_provenance() {
  local adb_bin=$1 serial=$2 output=$3 runtime=$4
  {
    printf 'captured_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'runtime=%s\n' "$runtime"
    printf 'serial=%s\n' "$serial"
    printf 'build_fingerprint=%s\n' "$(adb_for "$adb_bin" "$serial" shell getprop ro.build.fingerprint | tr -d '\r')"
    printf 'build_id=%s\n' "$(adb_for "$adb_bin" "$serial" shell getprop ro.build.id | tr -d '\r')"
    printf 'build_incremental=%s\n' "$(adb_for "$adb_bin" "$serial" shell getprop ro.build.version.incremental | tr -d '\r')"
    printf 'api_level=%s\n' "$(adb_for "$adb_bin" "$serial" shell getprop ro.build.version.sdk | tr -d '\r')"
    printf 'abi=%s\n' "$(adb_for "$adb_bin" "$serial" shell getprop ro.product.cpu.abi | tr -d '\r')"
    printf 'model=%s\n' "$(adb_for "$adb_bin" "$serial" shell getprop ro.product.model | tr -d '\r')"
  } >"$output"
}

collect_standard_evidence() {
  local adb_bin=$1 serial=$2 run_dir=$3 bugreport_timeout=$4 bugreport_status

  "$adb_bin" devices -l >"$run_dir/adb-devices.txt"
  adb_for "$adb_bin" "$serial" get-state >"$run_dir/target-state.txt"
  adb_for "$adb_bin" "$serial" shell getprop >"$run_dir/getprop.txt"
  adb_for "$adb_bin" "$serial" shell wm size >"$run_dir/wm-size.txt"
  adb_for "$adb_bin" "$serial" shell wm density >"$run_dir/wm-density.txt"
  adb_for "$adb_bin" "$serial" shell dumpsys activity processes >"$run_dir/dumpsys-activity-processes.txt" 2>&1
  adb_for "$adb_bin" "$serial" shell dumpsys window windows >"$run_dir/dumpsys-window.txt" 2>&1
  adb_for "$adb_bin" "$serial" shell dumpsys SurfaceFlinger >"$run_dir/dumpsys-surfaceflinger.txt" 2>&1
  adb_for "$adb_bin" "$serial" shell dumpsys activity exit-info >"$run_dir/exit-info.txt" 2>&1
  if [[ "${COLLECT_BUGREPORT:-1}" == 1 ]]; then
    if timeout "$bugreport_timeout" "$adb_bin" -s "$serial" bugreport "$run_dir/bugreport.zip" \
      >"$run_dir/bugreport-command.txt" 2>&1; then
      [[ -s "$run_dir/bugreport.zip" ]] || {
        printf 'bugreport command succeeded without a nonempty archive\n' >>"$run_dir/bugreport-command.txt"
        return 1
      }
    else
      bugreport_status=$?
      if (( bugreport_status == 124 )); then
        printf 'timed out after %s seconds; timeout is recorded as explicit incomplete evidence\n' \
          "$bugreport_timeout" >>"$run_dir/bugreport-command.txt"
      else
        printf 'bugreport failed with status %s\n' "$bugreport_status" >>"$run_dir/bugreport-command.txt"
        return "$bugreport_status"
      fi
    fi
  else
    printf 'disabled by COLLECT_BUGREPORT=0\n' >"$run_dir/bugreport-command.txt"
  fi
}

capture_ui_smoke() {
  local adb_bin=$1 serial=$2 run_dir=$3 display_size width height swipe_x swipe_start swipe_end attempt ui_ready=0

  adb_for "$adb_bin" "$serial" shell input keyevent KEYCODE_WAKEUP
  adb_for "$adb_bin" "$serial" shell wm dismiss-keyguard
  adb_for "$adb_bin" "$serial" shell input keyevent KEYCODE_HOME
  adb_for "$adb_bin" "$serial" shell settings put global window_animation_scale 0
  adb_for "$adb_bin" "$serial" shell settings put global transition_animation_scale 0
  adb_for "$adb_bin" "$serial" shell settings put global animator_duration_scale 0
  adb_for "$adb_bin" "$serial" shell cmd statusbar collapse >/dev/null 2>&1 || true
  sleep 3
  adb_for "$adb_bin" "$serial" exec-out screencap -p >"$run_dir/home.png"

  adb_for "$adb_bin" "$serial" shell wm size >"$run_dir/ui-display-size.txt"
  display_size=$(tr -d '\r' <"$run_dir/ui-display-size.txt" | awk -F ': ' '/Physical size|Override size/ {size=$2} END {print size}')
  [[ "$display_size" =~ ^([0-9]+)x([0-9]+)$ ]] || {
    printf 'could not parse display size: %s\n' "$display_size" >"$run_dir/ui-state-validation.txt"
    return 1
  }
  width=${BASH_REMATCH[1]}
  height=${BASH_REMATCH[2]}
  swipe_x=$((width / 2))
  # Status-bar interception requires the real top edge on current Android 17;
  # a proportional inset can land below the gesture region on small displays.
  swipe_start=1
  swipe_end=$((height * 4 / 5))

  # Android 17 can return success from `cmd statusbar expand-settings` without
  # changing state. Drive the native top-edge gesture instead. The visual and
  # semantic assertions, not input-command exit status, bound readiness.
  : >"$run_dir/statusbar-command.txt"
  : >"$run_dir/uiautomator.txt"
  : >"$run_dir/adb-pull-ui.txt"
  for attempt in 1 2 3 4 5; do
    printf 'attempt=%s method=top-edge-swipe\n' "$attempt" >>"$run_dir/statusbar-command.txt"
    adb_for "$adb_bin" "$serial" shell cmd statusbar collapse \
      >>"$run_dir/statusbar-command.txt" 2>&1 || true
    sleep 1
    adb_for "$adb_bin" "$serial" shell input swipe "$swipe_x" "$swipe_start" "$swipe_x" "$swipe_end" 800
    sleep 3
    adb_for "$adb_bin" "$serial" exec-out screencap -p >"$run_dir/quick-settings.png"

    rm -f -- "$run_dir/window.xml"
    adb_for "$adb_bin" "$serial" shell rm -f /sdcard/window.xml >/dev/null 2>&1 || true
    printf 'attempt=%s\n' "$attempt" >>"$run_dir/uiautomator.txt"
    if adb_for "$adb_bin" "$serial" shell uiautomator dump /sdcard/window.xml \
        >>"$run_dir/uiautomator.txt" 2>&1 \
        && adb_for "$adb_bin" "$serial" pull /sdcard/window.xml "$run_dir/window.xml" \
        >>"$run_dir/adb-pull-ui.txt" 2>&1 \
        && [[ -s "$run_dir/window.xml" ]] \
        && ! cmp -s "$run_dir/home.png" "$run_dir/quick-settings.png" \
        && grep -Fq 'package="com.android.systemui"' "$run_dir/window.xml"; then
      ui_ready=1
      break
    fi
    printf 'attempt=%s did not produce verified SystemUI Quick Settings\n' "$attempt" \
      >>"$run_dir/statusbar-command.txt"
    sleep 2
  done
  if [[ "$ui_ready" != 1 ]]; then
    printf 'Quick Settings visual and SystemUI hierarchy gates failed after five attempts\n' \
      >"$run_dir/ui-state-validation.txt"
    return 1
  fi
  printf 'PASS display=%sx%s swipe=%s,%s-%s,%s hierarchy=com.android.systemui\n' \
    "$width" "$height" "$swipe_x" "$swipe_start" "$swipe_x" "$swipe_end" \
    >"$run_dir/ui-state-validation.txt"

  {
    validate_png "$run_dir/home.png"
    validate_png "$run_dir/quick-settings.png"
  } >"$run_dir/png-validation.txt"
}

scan_target_failures() {
  local log_file=$1 output=$2 packages_csv=$3
  python3 - "$log_file" "$output" "$packages_csv" <<'PY'
import re
import sys

log_path, output_path, packages_csv = sys.argv[1:]
packages = [p.strip() for p in packages_csv.split(",") if p.strip()]
with open(log_path, encoding="utf-8", errors="replace") as stream:
    lines = stream.readlines()

hits = []
for index, line in enumerate(lines):
    direct = (
        "am_crash" in line
        or "am_anr" in line
        or "ANR in " in line
        or "Fatal signal" in line
    )
    if direct and any(package in line for package in packages):
        hits.append(line.rstrip())
    if "FATAL EXCEPTION" in line:
        block = "".join(lines[index:index + 16])
        if any(re.search(r"Process:\s*" + re.escape(package) + r"(?:,|\s|$)", block) for package in packages):
            hits.extend(item.rstrip() for item in lines[index:index + 16])

# Stable de-duplication keeps the evidence concise without discarding the raw log.
unique = list(dict.fromkeys(item for item in hits if item))
with open(output_path, "w", encoding="utf-8") as output:
    for item in unique:
        output.write(item + "\n")
raise SystemExit(1 if unique else 0)
PY
}
