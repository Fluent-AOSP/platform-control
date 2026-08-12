# Retired patch delivery

The ordered patch queue was retired after the Android 17 bring-up proved the build and runtime loop. It does not scale across SystemUI, Settings, Dialer, and other AOSP projects, and it created a second source of truth beside the actual project history.

Modified source now lives in independent public repositories:

- [`Fluent-AOSP/platform_frameworks_base`](https://github.com/Fluent-AOSP/platform_frameworks_base)
- [`Fluent-AOSP/platform_build_soong`](https://github.com/Fluent-AOSP/platform_build_soong)

The authoritative project set is pinned by [`Fluent-AOSP/android`](https://github.com/Fluent-AOSP/android) and mirrored as `manifests/fluent-android17.lock.xml` in this control repository. Future modified AOSP projects receive their own `Fluent-AOSP` repository and manifest pin.

Patch-era files remain available in this repository's Git history for milestone archaeology, but they are intentionally absent from the current tree and must not be applied to a Fluent manifest checkout. See [ADR 0002](../docs/adr/0002-project-repositories.md).
