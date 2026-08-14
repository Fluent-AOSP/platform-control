# Fluent on AOSP

A control and documentation repository for bringing a cohesive Microsoft Fluent visual system to AOSP while retaining Android behavior. Windows 11 is the canonical visual reference; the fork should look recognizably similar without replacing Android interaction or platform contracts. This repository does not contain the AOSP checkout itself.

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

The branch is a human-readable starting point, not a reproducibility guarantee. Builds use the exact revisions in the Fluent manifest and exported lock. See [ADR 0001](docs/adr/0001-aosp-baseline.md), the historical repository decision in [ADR 0002](docs/adr/0002-project-repositories.md), and the current full-history/non-fork policy in [ADR 0003](docs/adr/0003-full-history-independent-repositories.md).

## Design stance

- Use Windows 11 shell surfaces as the visual reference and implement them cohesively through **semantic tokens**, not scattered imitation or WinUI dependencies.
- Keep Android-owned dynamic palette generation and semantic role pairing while matching Fluent geometry, density, hierarchy, strokes, typography proportions, materials, and motion. The approved Quick Settings scope deliberately consumes fixed audited light/dark accent roles through its own semantic theme; this exception does not disable platform palette generation globally.
- Preserve scalable `sp`, locale fallback, 48 dp minimum targets, predictive back, insets, haptics, accessibility semantics, and adaptive layouts. Use only redistributable font/icon assets.
- Reproduce the visual intent of Acrylic/Mica with Android-native blur, tint, and opaque fallbacks where appropriate; do not copy desktop title bars, hover-only behavior, or compositor APIs that do not translate.
- Start with Quick Settings. Preserve its states, gestures, ordering, connectivity behavior, long-press actions, lockscreen rules, and accessibility.
- Integrate settings into the relevant existing Settings categories. **Never create a fork-name, “Fluent,” or OS-specific catch-all menu.**

Read the normative [Fluent implementation standard](docs/design/fluent-implementation-standard.md), [Fluent versus Material guide](docs/design/fluent-material-guide.md), and [customization architecture](docs/customization-architecture.md) before UI work. Coding agents must also follow [`AGENTS.md`](AGENTS.md).

## Repository map

- `AGENTS.md` — mandatory entry point for coding agents and automated contributors.
- `context.md` — durable project facts and scope boundary.
- `plan.md`, `ROADMAP.md` — gated execution plan and milestones.
- `docs/design/fluent-implementation-standard.md` — normative design, implementation, testing, and publication requirements.
- `docs/adr/` — architecture decisions.
- `docs/design/` — terminology and design mapping.
- `docs/host-bringup.md` — observed host/tool inventory and bring-up record.
- `docs/test-loop.md` — unattended evidence-loop specification.
- `docs/telegram-notifications.md` — private, low-noise feedback-channel setup and policy.
- `scripts/` — strict, parameterized operational entry points.
- `manifests/` — reviewed upstream and Fluent revision-locked Repo manifests.
- `docs/adr/0002-project-repositories.md` — historical transition from patches to project repositories.
- `docs/adr/0003-full-history-independent-repositories.md` — current independent, non-fork, full-upstream-history and authorship policy.

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
make init-sync        # syncs the pinned Fluent manifest into /mnt/aosp
make build            # builds via /mnt/aosp/out-fluent into /home/azureuser/aosp-out
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

M0–M3 are complete: the source tree is revision-locked, the product builds reproducibly, and the same-build Cuttlefish evidence loop is stable. Modified projects live in independent, non-fork `Fluent-AOSP` repositories with complete upstream history and are selected by the pinned [`Fluent-AOSP/android`](https://github.com/Fluent-AOSP/android) manifest. M4 publishes the expanded and phone-collapsed Quick Settings implementation through [`platform_frameworks_base`](https://github.com/Fluent-AOSP/platform_frameworks_base) commit `30634ab7b946`; full acceptance hardening remains in progress. See the [implementation standard](docs/design/fluent-implementation-standard.md), [ROADMAP.md](ROADMAP.md), and [Quick Settings foundation](docs/design/quick-settings-foundation.md).
