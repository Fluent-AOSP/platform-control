# ADR 0001: AOSP Android 17 and pinned manifests

- Status: Accepted
- Date: 2026-08-11

## Context

The project needs direct access to SystemUI, Settings, and Dialer UI; a low-churn upstream; and a virtual phone that can boot locally built platform images unattended on x86_64 KVM.

Candidates were AOSP, LineageOS, and PC-focused Android-x86/Bliss derivatives. A moving development branch or the moving `android-latest-release` alias would make unattended inputs drift.

## Decision

1. Base the project on the named AOSP branch `android17-release`.
2. Verify the branch ref before the initial sync. The bring-up observation is `29ace668ae756c7b8917c57abb440f6518844b0c`; advancement requires an explicit override and review.
3. Build `aosp_cf_x86_64_only_phone-aosp_current-userdebug`.
4. Use Cuttlefish for locally built platform images and the classic SDK Emulator only as bootstrap/fallback.
5. Preserve the initial upstream export as `manifests/aosp-android17.lock.xml`; export the active fork to `manifests/fluent-android17.lock.xml`. Treat changes to either source lock as dependency updates requiring review. ADR 0002 defines modified-project publication.
6. Record the manifest lock, Repo launcher version, host-package versions, build target, host image, build fingerprint, and image hashes with each accepted build.

A named branch improves intent but is still mutable. The revision-locked manifest is the source-input record; it does not promise bit-for-bit reproducible output by itself.

## Why AOSP

- It is the shortest path to `frameworks/base/packages/SystemUI/`, `packages/apps/Settings/`, and `packages/apps/Dialer/` without downstream framework/UI divergence.
- Cuttlefish and the selected product are first-party AOSP development paths.
- UI-only changes can prefer runtime resource overlays/product resources and narrow source commits in the affected project repository.
- It avoids inheriting unrelated product customization frameworks and merge burden.

## Alternatives

### LineageOS

Strong runner-up when Lineage features or its classic AVD workflow are product requirements. Rejected for the initial baseline because it adds downstream SystemUI/framework/Settings churn and its most prominent official emulator workflow is classic AVD rather than the selected Cuttlefish platform loop.

### `android-latest-release`

Useful for a compatibility monitor, not the product baseline. It is an intentionally moving alias that can cross release boundaries.

### AOSP `main`

Rejected for a UI-only product baseline because it offers more integration churn without a corresponding need for unreleased APIs.

### Bliss OS / Android-x86

Rejected because their PC/bare-metal and desktop-windowing goals add divergence unrelated to a phone-like Fluent UI fork.

## Consequences

- Initial sync/build remains large and long-running.
- Upstream branch updates and lock-file updates are deliberate operations.
- Direct source commits must be narrow, documented, and paired with screenshot/behavior tests.
- AOSP is not uniformly Apache-2.0; redistribution requires per-component notices, GPL obligations, and separate Google application/trademark review.
- Cuttlefish UI availability does not establish real carrier/IMS telephony behavior.

## Update policy

1. Run the existing lock in a clean source checkout and retain a known-good build/evidence baseline.
2. Fetch the named release branch and review its manifest delta.
3. Sync the candidate, export a new revision lock to a temporary file, and review every changed project revision.
4. Build and run the full closed loop.
5. Commit the lock update with compatibility notes. Never update the lock as an incidental side effect of an unrelated UI commit.

## Official references

- [AOSP quick start](https://source.android.com/docs/setup/start)
- [AOSP requirements](https://source.android.com/docs/setup/start/requirements)
- [Android 17 manifest](https://android.googlesource.com/platform/manifest/+/refs/heads/android17-release/default.xml)
- [Cuttlefish](https://source.android.com/docs/devices/cuttlefish)
- [LineageOS emulator guide](https://wiki.lineageos.org/emulator)
- [AOSP licenses](https://source.android.com/docs/setup/about/licenses)
