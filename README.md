# Fluent on AOSP

A control and documentation repository for adapting Microsoft Fluent Design to AOSP while retaining Android behavior. This is **not** a Windows skin and does not contain the AOSP checkout itself.

## Baseline

| Item | Selection |
|---|---|
| Upstream | AOSP `android17-release` |
| Observed manifest ref | `29ace668ae756c7b8917c57abb440f6518844b0c` |
| Product | `aosp_cf_x86_64_only_phone` |
| Lunch target | `aosp_cf_x86_64_only_phone-aosp_current-userdebug` |
| Primary runtime | locally built Cuttlefish |
| Bootstrap/fallback | SDK Emulator, API 36 `default;x86_64` |
| Source / output | `/mnt/aosp` / `/home/azureuser/aosp-out` |

The branch is a human-readable starting point, not a reproducibility guarantee. After sync, export and review a revision-locked manifest. See [ADR 0001](docs/adr/0001-aosp-baseline.md).

## Design stance

- Translate Fluent through **semantic tokens**, not hard-coded colors or WinUI controls.
- Keep Material You/dynamic-color role pairing and Android-native interaction contracts.
- Preserve Roboto/system typography, scalable `sp`, 48 dp minimum targets, predictive back, insets, haptics, accessibility semantics, and adaptive layouts.
- Treat Mica, desktop Acrylic, Segoe UI Variable, title bars, hover-first behavior, and Windows elevation numbers as Windows implementations—not portable requirements.
- Start with Quick Settings. Preserve its states, gestures, ordering, connectivity behavior, long-press actions, lockscreen rules, and accessibility.
- Integrate settings into the relevant existing Settings categories. **Never create a fork-name, “Fluent,” or OS-specific catch-all menu.**

Read the [Fluent versus Material guide](docs/design/fluent-material-guide.md) and [customization architecture](docs/customization-architecture.md) before UI work.

## Repository map

- `context.md` — durable project facts and scope boundary.
- `plan.md`, `ROADMAP.md` — gated execution plan and milestones.
- `docs/adr/` — architecture decisions.
- `docs/design/` — terminology and design mapping.
- `docs/host-bringup.md` — observed host/tool inventory and bring-up record.
- `docs/test-loop.md` — unattended evidence-loop specification.
- `docs/telegram-notifications.md` — private, low-noise feedback-channel setup and policy.
- `scripts/` — strict, parameterized operational entry points.
- `manifests/` — reviewed revision-locked Repo manifests.

## Quick start

All scripts support `--help`; mutation-capable scripts also support `--dry-run` where meaningful.

```bash
make help
make validate         # syntax, help modes, and static safety contract
make preflight        # read-only host checks
make init-sync-dry-run
make build-dry-run
make smoke-sdk-dry-run
make smoke-cvd-dry-run
```

Real operations are explicit:

```bash
make init-sync        # network/disk intensive; initializes and syncs /mnt/aosp
make build            # builds into /home/azureuser/aosp-out
make smoke-sdk        # resets the dedicated bootstrap AVD and collects evidence
make smoke-cvd        # boots locally built images and collects evidence
```

Override paths and identifiers via the environment:

```bash
AOSP_ROOT=/mnt/aosp \
OUT_DIR=/home/azureuser/aosp-out \
ARTIFACT_ROOT=/home/azureuser/android-test-artifacts \
make preflight
```

### Android SDK license boundary

The SDK smoke script runs an already installed SDK by default. It does not install packages or accept agreements. Optional package installation requires `INSTALL_MISSING_SDK_PACKAGES=1`. License acceptance is a separate, deliberately conspicuous opt-in:

```bash
ACCEPT_ANDROID_SDK_LICENSES=I_HAVE_AUTHORITY_TO_ACCEPT \
INSTALL_MISSING_SDK_PACKAGES=1 \
scripts/sdk-emulator-smoke.sh --install-missing --dry-run
```

Remove `--dry-run` only after an authorized person has reviewed the applicable terms. The opt-in may accept more SDK agreements than the one package needs; automation is not legal authority.

### Telegram feedback channel

The selected notification path is a Bot API private chat with a local mode-0600 credential file. Enter the token only through the hidden terminal prompt—never in Git, shell arguments, or chat:

```bash
make telegram-configure
make telegram-test
```

Once configured, operational scripts send only sync/build/verification success or failure. The first passing locally built Cuttlefish run additionally sends its raw Quick Settings screenshot from a new test-owned instance and requests design feedback; later passes do not reattach it automatically. `NOTIFY_TELEGRAM=0` suppresses a run; the default `auto` mode sends only when the secret file exists. See [Telegram notifications](docs/telegram-notifications.md).

## Safety and evidence

Scripts do not clean AOSP or build outputs, do not stop unrelated virtual devices, and bind ADB targets to locked instance/port ownership. Smoke runs use stage deadlines, owned-process traps, unique evidence directories, PNG structural checks, required UI hierarchy/dumpsys capture, bounded bugreport (unless disabled explicitly), target-package Java/native crash and ANR classification, and a successful owned-instance stop before writing `PASS`. The SDK loop uses `-wipe-data` only on the named dedicated test AVD to ensure a clean run.

No script pushes or publishes. Only the explicit Telegram setup/notifier and documented milestone hooks contact an external notification service. The credential remains outside the repository in a checked mode-0600 file.

## Status

M0 foundation and M1 source sync are complete: the clean AOSP checkout is pinned by `manifests/aosp-android17.lock.xml`. The earlier SDK bootstrap run proved basic KVM/ADB/screenshot mechanics but predates the current full evidence contract and is retained as legacy bring-up evidence. The current gate is M2: the first locked AOSP build, followed by the locally built Cuttlefish loop. See [ROADMAP.md](ROADMAP.md).
