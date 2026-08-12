#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/aosp-build.sh [--dry-run] [--help]

Build the approved Cuttlefish phone target without cleaning source or output.

Environment:
  AOSP_ROOT       Source path (default: /mnt/aosp)
  OUT_DIR         Physical output storage (default: /home/azureuser/aosp-out)
  AOSP_OUT_ALIAS  Source-root alias passed to AOSP (default: out-fluent)
  LUNCH_TARGET    Default/approved: aosp_cf_x86_64_only_phone-aosp_current-userdebug
  ALLOW_LUNCH_TARGET_OVERRIDE  1 permits a reviewed target override
  BUILD_JOBS      Default: 12 (conservative for the 62 GiB reference host)
  BUILD_TIMEOUT   Default: 43200 seconds
  ARTIFACT_ROOT   Build evidence root (default: /home/azureuser/android-test-artifacts)

Dry-run validates parameters and prints the intended stages without sourcing or
building AOSP. No clean/clobber operation is performed.
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
AOSP_OUT_ALIAS=${AOSP_OUT_ALIAS:-out-fluent}
APPROVED_LUNCH_TARGET=aosp_cf_x86_64_only_phone-aosp_current-userdebug
LUNCH_TARGET=${LUNCH_TARGET:-$APPROVED_LUNCH_TARGET}
ALLOW_LUNCH_TARGET_OVERRIDE=${ALLOW_LUNCH_TARGET_OVERRIDE:-0}
BUILD_JOBS=${BUILD_JOBS:-12}
BUILD_TIMEOUT=${BUILD_TIMEOUT:-43200}
ARTIFACT_ROOT=${ARTIFACT_ROOT:-/home/azureuser/android-test-artifacts}

require_positive_integer BUILD_JOBS "$BUILD_JOBS"
require_positive_integer BUILD_TIMEOUT "$BUILD_TIMEOUT"
[[ "$ALLOW_LUNCH_TARGET_OVERRIDE" == 0 || "$ALLOW_LUNCH_TARGET_OVERRIDE" == 1 ]] || die 'ALLOW_LUNCH_TARGET_OVERRIDE must be 0 or 1'
if [[ "$LUNCH_TARGET" != "$APPROVED_LUNCH_TARGET" ]]; then
  [[ "$ALLOW_LUNCH_TARGET_OVERRIDE" == 1 ]] || die "LUNCH_TARGET must be $APPROVED_LUNCH_TARGET"
  warn "allowing reviewed lunch target override: $LUNCH_TARGET"
fi

if [[ "$DRY_RUN" == 1 ]]; then
  printf 'DRY-RUN: require %q and its envsetup/manifest files\n' "$AOSP_ROOT"
  quote_command install -d -m 0755 "$OUT_DIR" "$ARTIFACT_ROOT"
  printf 'DRY-RUN: require %q to resolve to physical output %q\n' "$AOSP_ROOT/$AOSP_OUT_ALIAS" "$OUT_DIR"
  printf 'DRY-RUN: source %q; lunch %q with OUT_DIR=%q; timeout %q m -j%q\n' \
    "$AOSP_ROOT/build/envsetup.sh" "$LUNCH_TARGET" "$AOSP_OUT_ALIAS" "$BUILD_TIMEOUT" "$BUILD_JOBS"
  printf 'DRY-RUN: record manifest, environment, product/host outputs, and image checksums\n'
  exit 0
fi

require_command timeout
require_command tee
require_command sha256sum
require_command python3
require_dir "$AOSP_ROOT/.repo"
require_file "$AOSP_ROOT/build/envsetup.sh"
install -d -m 0755 "$OUT_DIR" "$ARTIFACT_ROOT"
prepare_aosp_out_alias "$AOSP_ROOT" "$OUT_DIR" "$AOSP_OUT_ALIAS"
run_dir=$(new_run_dir "$ARTIFACT_ROOT" aosp-build)
{
  for tool in bash git make ninja python3 javac; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '## %s (%s)\n' "$tool" "$(command -v "$tool")"
      "$tool" --version 2>&1 | head -3 || true
    else
      printf '## %s unavailable\n' "$tool"
    fi
  done
  printf '## repo\n'
  repo version 2>&1 || true
  if command -v dpkg-query >/dev/null 2>&1; then
    printf '## host packages\n'
    dpkg-query -W -f='${Package}\t${Version}\n' \
      git-core git-lfs make ninja-build python3 repo 2>/dev/null || true
  fi
} >"$run_dir/tool-versions.txt"
notification_sent=0
build_cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if (( status != 0 )); then
    [[ -e "$run_dir/result.txt" ]] || printf 'FAIL exit=%d\n' "$status" >"$run_dir/result.txt"
    if [[ "$notification_sent" == 0 ]]; then
      notify_telegram_safe failure 'AOSP build failed' \
        "The $LUNCH_TARGET build exited with status $status. Evidence: $run_dir"
    fi
  fi
  exit "$status"
}
trap build_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

{
  printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'aosp_root=%s\n' "$AOSP_ROOT"
  printf 'out_storage_dir=%s\n' "$OUT_DIR"
  printf 'aosp_out_alias=%s\n' "$AOSP_OUT_ALIAS"
  printf 'lunch_target=%s\n' "$LUNCH_TARGET"
  printf 'build_jobs=%s\n' "$BUILD_JOBS"
  printf 'repo_launcher=%s\n' "$(repo version 2>&1 | head -1)"
  printf 'host=%s\n' "$(uname -srvmo)"
} >"$run_dir/provenance.txt"

(
  cd "$AOSP_ROOT"
  export OUT_DIR="$AOSP_OUT_ALIAS"
  repo manifest -r -o "$run_dir/source-manifest.xml"
  # AOSP envsetup and the shell functions it defines (including lunch/m) are
  # not authored for nounset. This is isolated to the build subshell.
  set +u
  # shellcheck disable=SC1091
  source build/envsetup.sh
  lunch "$LUNCH_TARGET"
  {
    printf 'TARGET_PRODUCT=%s\n' "${TARGET_PRODUCT:-}"
    printf 'TARGET_BUILD_VARIANT=%s\n' "${TARGET_BUILD_VARIANT:-}"
    printf 'ANDROID_PRODUCT_OUT=%s\n' "${ANDROID_PRODUCT_OUT:-}"
    printf 'ANDROID_HOST_OUT=%s\n' "${ANDROID_HOST_OUT:-}"
  } >>"$run_dir/provenance.txt"
  timeout "$BUILD_TIMEOUT" m -j"$BUILD_JOBS"
) 2>&1 | tee "$run_dir/build.log"

product_out=$(awk -F= '$1 == "ANDROID_PRODUCT_OUT" {print substr($0, index($0, "=") + 1)}' "$run_dir/provenance.txt" | tail -1)
host_out=$(awk -F= '$1 == "ANDROID_HOST_OUT" {print substr($0, index($0, "=") + 1)}' "$run_dir/provenance.txt" | tail -1)
[[ -n "$product_out" && -d "$product_out" ]] || die 'build completed but ANDROID_PRODUCT_OUT was not recorded as a directory'
[[ -n "$host_out" && -d "$host_out" ]] || die 'build completed but ANDROID_HOST_OUT was not recorded as a directory'

find "$product_out" -maxdepth 1 -type f \
  \( -name '*.img' -o -name '*-img-*.zip' -o -name 'android-info.txt' \) \
  -print0 | sort -z | xargs -0 -r sha256sum >"$run_dir/product-checksums.sha256"
[[ -s "$run_dir/product-checksums.sha256" ]] || die 'no product image files were found for checksumming'
python3 - "$product_out" "$run_dir/build-fingerprint.txt" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])

# Product builds emit the canonical device fingerprint directly. Prefer this
# over partition-scoped build.prop keys such as ro.system.build.fingerprint.
fingerprint_files = sorted(root.glob("build_fingerprint-*.txt"))
for path in fingerprint_files:
    try:
        value = path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        continue
    if value:
        out.write_text(value + "\n", encoding="utf-8")
        raise SystemExit(0)

property_keys = (
    "ro.build.fingerprint=",
    "ro.vendor.build.fingerprint=",
    "ro.product.build.fingerprint=",
    "ro.system.build.fingerprint=",
)
for path in sorted(root.glob("**/build.prop")):
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        continue
    for key in property_keys:
        for line in lines:
            if line.startswith(key):
                value = line.split("=", 1)[1].strip()
                if value:
                    out.write_text(value + "\n", encoding="utf-8")
                    raise SystemExit(0)
raise SystemExit("build fingerprint was not found in product outputs")
PY
printf 'completed_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$run_dir/provenance.txt"
printf 'PASS\n' >"$run_dir/result.txt"
notify_telegram_safe success 'AOSP build completed' \
  "The $LUNCH_TARGET image build completed. Cuttlefish verification is the next gate. Evidence: $run_dir"
notification_sent=1
log "build passed; evidence: $run_dir"
