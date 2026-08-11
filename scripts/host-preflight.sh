#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/host-preflight.sh [--help]

Read-only checks for the AOSP build and virtual-device host.

Environment:
  AOSP_ROOT            Source path (default: /mnt/aosp)
  OUT_DIR              Build output path (default: /home/azureuser/aosp-out)
  ARTIFACT_ROOT        Evidence path (default: /home/azureuser/android-test-artifacts)
  SOURCE_MIN_GIB       Required free GiB on source filesystem (default: 250)
  OUT_MIN_GIB          Required free GiB on output filesystem (default: 150)
  MEMORY_MIN_GIB       Required physical-memory GiB (default: 60)
  REQUIRE_CVD_GROUPS   1 to require kvm/cvdnetwork/render membership (default: 1)
EOF
}

[[ ${1:-} != --help && ${1:-} != -h ]] || { usage; exit 0; }
[[ $# -eq 0 ]] || die "unknown argument: $1"

AOSP_ROOT=${AOSP_ROOT:-/mnt/aosp}
OUT_DIR=${OUT_DIR:-/home/azureuser/aosp-out}
ARTIFACT_ROOT=${ARTIFACT_ROOT:-/home/azureuser/android-test-artifacts}
SOURCE_MIN_GIB=${SOURCE_MIN_GIB:-250}
OUT_MIN_GIB=${OUT_MIN_GIB:-150}
MEMORY_MIN_GIB=${MEMORY_MIN_GIB:-60}
REQUIRE_CVD_GROUPS=${REQUIRE_CVD_GROUPS:-1}

require_positive_integer SOURCE_MIN_GIB "$SOURCE_MIN_GIB"
require_positive_integer OUT_MIN_GIB "$OUT_MIN_GIB"
require_positive_integer MEMORY_MIN_GIB "$MEMORY_MIN_GIB"
[[ "$REQUIRE_CVD_GROUPS" == 0 || "$REQUIRE_CVD_GROUPS" == 1 ]] || die "REQUIRE_CVD_GROUPS must be 0 or 1"

failures=0
checks=0
pass() { checks=$((checks + 1)); printf 'PASS  %s\n' "$*"; }
fail() { checks=$((checks + 1)); failures=$((failures + 1)); printf 'FAIL  %s\n' "$*" >&2; }

for command in bash git repo python3 make ninja timeout flock df findmnt; do
  if command -v "$command" >/dev/null 2>&1; then pass "command: $command"; else fail "missing command: $command"; fi
done

if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  if (exec 3<>/dev/kvm) 2>/dev/null; then pass '/dev/kvm is openable'; else fail '/dev/kvm exists but cannot be opened'; fi
else
  fail '/dev/kvm must be a readable/writable character device'
fi

if grep -Eqm1 '\b(vmx|svm)\b' /proc/cpuinfo; then
  pass 'CPU virtualization flag exposed'
else
  fail 'CPU virtualization flag not exposed'
fi

if [[ "$REQUIRE_CVD_GROUPS" == 1 ]]; then
  groups_now=" $(id -Gn) "
  for group in kvm cvdnetwork render; do
    if [[ "$groups_now" == *" $group "* ]]; then
      pass "group membership: $group"
    else
      fail "current login lacks group: $group"
    fi
  done
fi

nsjail="$AOSP_ROOT/prebuilts/build-tools/linux-x86/bin/nsjail"
if [[ -x "$nsjail" ]]; then
  if timeout 15 "$nsjail" -H android-build -e -u nobody -g nogroup \
      -R / -B /tmp --disable_clone_newcgroup -- /bin/true >/dev/null 2>&1; then
    pass 'AOSP nsjail can create a build sandbox'
  else
    fail 'AOSP nsjail cannot create a build sandbox; check AppArmor user-namespace policy'
  fi
else
  warn "AOSP nsjail is absent; skipped sandbox probe ($nsjail)"
fi

memory_bytes=$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo)
minimum_memory_bytes=$((MEMORY_MIN_GIB * 1024 * 1024 * 1024))
if awk -v actual="$memory_bytes" -v required="$minimum_memory_bytes" 'BEGIN {exit !(actual >= required)}'; then
  pass "physical memory >= ${MEMORY_MIN_GIB} GiB"
else
  fail "physical memory below ${MEMORY_MIN_GIB} GiB"
fi

check_path_space() {
  local label=$1 path=$2 minimum_gib=$3 parent available required
  if [[ -e "$path" ]]; then
    parent=$path
  else
    parent=$(dirname -- "$path")
  fi
  [[ -d "$parent" ]] || { fail "$label parent directory absent: $parent"; return; }
  available=$(df -PB1 "$parent" | awk 'NR==2 {print $4}')
  required=$((minimum_gib * 1024 * 1024 * 1024))
  if (( available >= required )); then
    pass "$label filesystem has >= ${minimum_gib} GiB free ($parent)"
  else
    fail "$label filesystem has less than ${minimum_gib} GiB free ($parent)"
  fi
  if [[ -w "$parent" ]]; then
    pass "$label parent is writable ($parent)"
  else
    fail "$label parent is not writable ($parent)"
  fi
}

check_path_space source "$AOSP_ROOT" "$SOURCE_MIN_GIB"
check_path_space output "$OUT_DIR" "$OUT_MIN_GIB"

artifact_parent=$ARTIFACT_ROOT
[[ -d "$artifact_parent" ]] || artifact_parent=$(dirname -- "$artifact_parent")
if [[ -d "$artifact_parent" && -w "$artifact_parent" ]]; then
  pass "artifact path is writable ($artifact_parent)"
else
  fail "artifact path is not writable ($artifact_parent)"
fi

if command -v emulator >/dev/null 2>&1; then
  accel_output=''
  if accel_output=$(emulator -accel-check 2>&1); then
    pass 'Android Emulator acceleration check'
  else
    fail 'Android Emulator acceleration check'
  fi
  printf '%s\n' "$accel_output"
else
  warn 'emulator is not on PATH; skipped emulator -accel-check'
fi

printf '\nHost: %s\n' "$(uname -srvmo)"
printf 'CPU(s): %s\n' "$(nproc)"
printf 'Source: %s\nOutput: %s\nArtifacts: %s\n' "$AOSP_ROOT" "$OUT_DIR" "$ARTIFACT_ROOT"
printf 'Checks: %d; failures: %d\n' "$checks" "$failures"
(( failures == 0 )) || exit 1
