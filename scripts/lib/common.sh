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
  local adb_bin=$1 serial=$2 run_dir=$3

  adb_for "$adb_bin" "$serial" shell input keyevent KEYCODE_WAKEUP
  adb_for "$adb_bin" "$serial" shell wm dismiss-keyguard
  adb_for "$adb_bin" "$serial" shell input keyevent KEYCODE_HOME
  adb_for "$adb_bin" "$serial" shell settings put global window_animation_scale 0
  adb_for "$adb_bin" "$serial" shell settings put global transition_animation_scale 0
  adb_for "$adb_bin" "$serial" shell settings put global animator_duration_scale 0
  sleep 3
  adb_for "$adb_bin" "$serial" exec-out screencap -p >"$run_dir/home.png"

  if ! adb_for "$adb_bin" "$serial" shell cmd statusbar expand-settings; then
    adb_for "$adb_bin" "$serial" shell input swipe 540 0 540 1800 500
    adb_for "$adb_bin" "$serial" shell input swipe 540 0 540 1800 500
  fi
  sleep 3
  adb_for "$adb_bin" "$serial" exec-out screencap -p >"$run_dir/quick-settings.png"
  adb_for "$adb_bin" "$serial" shell uiautomator dump /sdcard/window.xml \
    >"$run_dir/uiautomator.txt" 2>&1
  adb_for "$adb_bin" "$serial" pull /sdcard/window.xml "$run_dir/window.xml" \
    >"$run_dir/adb-pull-ui.txt" 2>&1
  [[ -s "$run_dir/window.xml" ]] || return 1

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
