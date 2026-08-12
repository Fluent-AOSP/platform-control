# Unattended UI test-loop specification

## Goal

Provide a closed, deterministic-enough loop for booting Android, exercising UI, capturing visual/semantic evidence, classifying platform failures, and shutting down without user interaction. Cuttlefish validates locally built AOSP; the classic SDK Emulator is bootstrap/fallback only.

## State machine

1. **Preflight** — validate commands, readable/writable KVM, groups, paths, disk, memory, port/serial uniqueness, and expected build outputs.
2. **Acquire lock** — one lock per AVD or Cuttlefish instance. Refuse overlap rather than target an ambiguous device.
3. **Create run directory** — UTC run ID, restrictive umask, provenance file, and separate runtime home.
4. **Launch** — start only the named AVD/instance; record the owned PID where available. Do not kill unrelated devices.
5. **Transport deadline** — wait for the exact ADB serial, connecting to the exact TCP serial when applicable.
6. **Framework deadline** — poll `sys.boot_completed=1`; do not use a fixed sleep as readiness proof.
7. **Package-manager deadline** — require `cmd package list packages` to succeed.
8. **Baseline** — record fingerprint, build ID, API, ABI, model, display, `adb devices -l`, manifest/tool provenance, and clear logcat.
9. **Observe continuously** — start `logcat -b all -v threadtime` before UI actions.
10. **Drive/assert** — wake, dismiss keyguard if allowed, go home, disable animations for deterministic smoke evidence, expand Quick Settings using the live display dimensions, and retry the transient UI hierarchy dump within a fixed attempt bound. Require the Quick Settings image to differ from home and the hierarchy to identify SystemUI. Prefer instrumentation/UI Automator semantic assertions over coordinate taps for later tests.
11. **Collect always** — screenshots, UI XML, logcat, dumpsys, exit info, and a bounded bugreport. Missing core evidence fails the run. A bugreport timeout or explicit disable is recorded as an allowed evidence exception; other bugreport failures fail.
12. **Validate/classify** — structurally validate PNGs and scan for target-package Java/native crash and ANR evidence. Raw “FATAL” keyword matching is insufficient.
13. **Stop** — stop only the owned AVD/instance. A bounded TERM/KILL fallback may clean an owned Emulator PID after failure, but an accepted run requires the graceful owned stop to succeed. Preserve evidence on every exit and write `PASS` only after stop.

## Runtime roles

### SDK Emulator

- Package: `system-images;android-36;default;x86_64` (AOSP `default`, not Google APIs/Play).
- AVD: dedicated `aosp-bootstrap-api36`.
- Determinism: `-no-window -no-audio -no-boot-anim -no-snapshot -no-metrics -wipe-data -accel on -gpu swiftshader_indirect`.
- Serial: derived from an explicit even console port, default `emulator-5554`.
- Scope: proves host KVM, adb, UI driving, and evidence mechanics. It does not run project-built SystemUI.

`-wipe-data` intentionally resets the named dedicated smoke AVD. Do not point the script at a personal/development AVD whose data must persist.

### Locally built Cuttlefish

- Lunch: `aosp_cf_x86_64_only_phone-aosp_current-userdebug`.
- Host tools: use `$ANDROID_HOST_OUT/bin` from the same build that produced `$ANDROID_PRODUCT_OUT`; never let a stale downloaded host bundle win in `PATH`.
- Runtime home: unique to the run so stop/reset commands address only that run.
- Serial: derived from the locked instance (`127.0.0.1:` plus `6520 + instance - 1`), checked for pre-existing listeners/transports, and verified against the generated owned Cuttlefish configuration after launch. Clean-stop probing permits rebinding stale `TIME_WAIT` tuples but remains blocked by an actual listener; cleanup disconnects and verifies both ADB aliases for only the prevalidated owned port.
- Scope: acceptance runtime for every UI change.

Do not depend on an unattended “latest” Cuttlefish CI artifact downloader. No such downloader is checked in. If a prebuilt bundle is ever approved, mirror a human-selected image and matching host package with identical build ID and checksums; the baseline script deliberately uses only same-build local images and host tools.

## Stage deadlines

Defaults are intentionally overridable:

| Stage | Emulator | Cuttlefish |
|---|---:|---:|
| ADB transport | 240 s | 240 s |
| `sys.boot_completed` | 420 s | 420 s |
| Package manager | 90 s | 90 s |
| Bugreport | 300 s | 300 s |
| Graceful stop | 30 s | 60 s |

An outer CI job timeout must exceed the sum and upload the run directory even on timeout.

## Required evidence

Every accepted run should contain:

- `result.txt` and stage/error context;
- launch stdout/stderr and owned PID when available;
- `provenance.txt`, `adb-devices.txt`, `getprop.txt`, display size/density;
- `home.png`, `quick-settings.png`, and their validation output;
- UI hierarchy XML and dump command output;
- continuous all-buffer logcat plus event-focused crash/ANR scan;
- `dumpsys activity`, window, and SurfaceFlinger snapshots;
- bounded bugreport unless an explicit resource policy disables it;
- manifest/build output identity for built Cuttlefish runs;
- stop result.

Raw evidence is retained even when classification passes.

## Screenshot validation and comparison

The smoke gate checks PNG signature, IHDR dimensions, and a minimum file size. Later visual regression uses pinned runtime/rendering versions and combines:

- semantic assertions from UI Automator/instrumentation;
- tolerant image comparison;
- masks for clocks, cursors, dynamic signal state, and other nondeterminism;
- multiple wallpaper/dynamic-color and contrast configurations.

Never use a pixel score alone to decide correctness.

## Crash and ANR policy

- Clear logs immediately before the action phase.
- Capture all buffers continuously.
- Flag `am_crash`/`am_anr`, `ANR in`, Java `FATAL EXCEPTION` blocks whose process is a target package, and native fatal-signal lines attributable to a target package.
- Initial targets: `com.android.systemui` and `com.android.settings`; add the tested package explicitly.
- Preserve `dumpsys activity exit-info` and bugreport as corroborating evidence.
- Do not fail merely because unrelated platform text contains “FATAL” or “ANR.”
- Before trusting automation, validate the detector against deliberate Java-crash, ANR, and native-fatal fixtures, then show that a clean fixture passes.

## UI acceptance matrix for Quick Settings

At minimum: active/inactive/unavailable tile state; long-click destination; Internet/connectivity panel; tile editing/order; portrait/landscape; compact/expanded window; light/dark; several wallpapers/dynamic palettes; contrast levels; animations on/off; TalkBack; RTL; 200% font scale; keyboard/D-pad; lockscreen/redacted notifications; screenshot/recording privacy; and frame performance.

## User feedback boundary

Telegram delivery is configured separately through a mode-0600 file outside Git. The SDK bootstrap may send a setup/smoke confirmation; it attaches a screenshot only when the dedicated AVD is wiped. The first **locally built** image pass is the design-feedback gate: the Cuttlefish loop sends the raw Quick Settings screenshot from its new test-owned instance and records a local marker so later passes do not attach it automatically. This is not image redaction; privacy comes from using a fresh AOSP test instance with no account or user data. Automatic delivery is otherwise limited to sync, build, and verification success/failure. Raw logs, environment dumps, tokens, and bugreports are never attached. See [Telegram notifications](telegram-notifications.md).

## Commands

```bash
make smoke-sdk-dry-run
make smoke-sdk
make smoke-cvd-dry-run
make smoke-cvd
```

See each script's `--help` for environment parameters.

## Official references

- [Cuttlefish overview](https://source.android.com/docs/devices/cuttlefish)
- [Cuttlefish get started](https://source.android.com/docs/devices/cuttlefish/get-started)
- [Cuttlefish reset/restart](https://source.android.com/docs/devices/cuttlefish/restart)
- [Android Emulator command line](https://developer.android.com/studio/run/emulator-commandline)
- [ADB](https://developer.android.com/tools/adb)
- [Bugreports](https://developer.android.com/studio/debug/bug-report)
- [AOSP bugreport analysis](https://source.android.com/docs/core/tests/debug/read-bug-reports)
- [ANRs](https://developer.android.com/topic/performance/vitals/anr)
