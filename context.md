# Project context

This repository is the control plane for a UI-only Fluent Design adaptation of AOSP. The Android source checkout and build output deliberately live outside this Git repository.

## Approved baseline

- Upstream: AOSP `android17-release`.
- Manifest ref observed during bring-up: `29ace668ae756c7b8917c57abb440f6518844b0c`.
- Product: `aosp_cf_x86_64_only_phone`.
- Lunch target: `aosp_cf_x86_64_only_phone-aosp_current-userdebug`.
- Primary built-image runtime: Cuttlefish.
- Bootstrap/fallback runtime: classic Android SDK Emulator using the AOSP `default` x86_64 API 36 image.
- Source path: `/mnt/aosp` (override with `AOSP_ROOT`).
- Build output: `/home/azureuser/aosp-out` (override with `OUT_DIR`).
- Evidence root: `/home/azureuser/android-test-artifacts` (override with `ARTIFACT_ROOT`).

## Product boundary

Only UI design is in scope. Preserve Android behavior, accessibility, navigation, safety, telephony semantics, dynamic color contracts, and Settings information architecture. Fluent settings belong in their existing relevant categories; there must be no catch-all fork/OS-specific Settings menu.

Quick Settings is the first customization surface. Settings and Dialer follow only after the built-image loop is stable.

## Established evidence

The bootstrap loop passed at `/home/azureuser/android-test-artifacts/bootstrap-20260811T152831Z` with valid 1080×2400 home and Quick Settings PNGs, explicit ADB targeting, and a clean startup crash-signal scan. The image fingerprint was:

`Android/sdk_phone64_x86_64/emu64x:16/BE2A.250530.026.D1/13818094:userdebug/test-keys`

See `docs/host-bringup.md` for the full inventory and `docs/test-loop.md` for the repeatable contract.
