# Project context

This repository is the control plane for a UI-only Fluent Design adaptation of AOSP. The Android source checkout and build output deliberately live outside this Git repository.

## Approved baseline

- Upstream: AOSP `android17-release` from Android Gitiles.
- Upstream manifest ref observed during bring-up: `29ace668ae756c7b8917c57abb440f6518844b0c`.
- Fluent manifest: `https://github.com/Fluent-AOSP/android`, branch `fluent-android17`, with builds pinned to exact project revisions.
- Modified projects are independent, non-fork `Fluent-AOSP` repositories with complete upstream history. Android Gitiles is authoritative for the selected revisions; GitHub Importer may use archived `aosp-mirror` only as a server-side history transport seed, as defined by ADR 0003.
- Product: `aosp_cf_x86_64_only_phone`.
- Lunch target: `aosp_cf_x86_64_only_phone-aosp_current-userdebug`.
- Primary built-image runtime: Cuttlefish.
- Bootstrap/fallback runtime: classic Android SDK Emulator using the AOSP `default` x86_64 API 36 image.
- Source path: `/mnt/aosp` (override with `AOSP_ROOT`).
- Build output: `/home/azureuser/aosp-out` (override with `OUT_DIR`).
- Evidence root: `/home/azureuser/android-test-artifacts` (override with `ARTIFACT_ROOT`).

## Product boundary

Only UI design is in scope. Preserve Android behavior, accessibility, navigation, safety, telephony semantics, dynamic color generation, and Settings information architecture. A required Fluent affordance may expose an existing Android action only through its platform-owned controller or setting; it must not implement new device behavior. The approved auto-brightness affordance is such an integration and must delegate to Android's existing automatic-brightness mode. Fluent settings belong in their existing relevant categories; there must be no catch-all fork/OS-specific Settings menu.

Quick Settings is the first customization surface. Android continues to own dynamic palette generation globally, while the approved Quick Settings scope intentionally consumes fixed audited light/dark accent role pairs through its semantic theme layer. Its canonical composition is the Windows 11 flyout: a floating Acrylic panel, three compact tile columns with labels below the surfaces, independent brightness/volume rails, and a distinct footer. Settings and Dialer follow only after the built-image loop is stable.

## Established evidence

The bootstrap loop passed at `/home/azureuser/android-test-artifacts/bootstrap-20260811T152831Z` with valid 1080×2400 home and Quick Settings PNGs, explicit ADB targeting, and a clean startup crash-signal scan. The image fingerprint was:

`Android/sdk_phone64_x86_64/emu64x:16/BE2A.250530.026.D1/13818094:userdebug/test-keys`

See `docs/host-bringup.md` for the full inventory and `docs/test-loop.md` for the repeatable contract.
