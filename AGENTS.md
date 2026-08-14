# Fluent AOSP agent instructions

These instructions apply to every coding agent and automated contributor working from this repository.

## Mandatory first step

Before proposing or editing UI code, read:

1. [`docs/design/fluent-implementation-standard.md`](docs/design/fluent-implementation-standard.md) — normative requirements;
2. [`context.md`](context.md) — product and environment boundary;
3. [`docs/customization-architecture.md`](docs/customization-architecture.md) — implementation layering;
4. [`docs/design/fluent-material-guide.md`](docs/design/fluent-material-guide.md) — Fluent-to-Android translation;
5. the relevant surface specification;
6. [`docs/test-loop.md`](docs/test-loop.md) — evidence and runtime acceptance;
7. applicable ADRs.

For Quick Settings, also read [`docs/design/quick-settings-foundation.md`](docs/design/quick-settings-foundation.md).

## Hard rules

- Preserve Android behavior, accessibility, security, privacy, state production, interaction, navigation, insets, haptics, and adaptive layout.
- Follow Windows 11 and official Fluent/WinUI guidance for visual language. Do not invent “official” Microsoft values.
- Implement complete visual relationships—layout, density, typography, geometry, stroke, materials, icons, states, and motion—not isolated blue/rounded styling.
- Use semantic tokens. Do not scatter raw values.
- Do not create fake controls or replace live state with static artwork.
- Keep all interaction targets at least 48 dp.
- Use compositor-owned backdrop blur for Acrylic and provide opaque/no-blur/reduced-transparency/privacy/performance fallbacks.
- Never commit proprietary Segoe binaries. Public code may request the optional product family `segoe-ui` with safe fallback.
- Use only reviewed, pinned, licensed assets. Preserve unknown/OEM/custom icons.
- Do not add a Fluent/fork/custom-ROM catch-all Settings category.
- Do not claim completion from one screenshot or a successful compile.

## Repository and publication rules

- Modified AOSP projects live in independent, non-fork `Fluent-AOSP` repositories with complete upstream history.
- Preserve individual Fluent commits; do not squash unrelated work.
- Project-authored commits MUST use:
  - Name: `Foxtrot47`
  - Email: `jjneutron@outlook.com`
- Do not use VM-derived, Ubuntu, automation, build-service, or co-author identities unless project authority explicitly changes this policy.
- Use Conventional Commit subjects for new work.
- Do not push unless the task authorizes publication and applicable validation/review gates pass.
- After publishing a project change, pin it in `Fluent-AOSP/android` and update the exported `platform-control` lock.

## Required workflow

1. Verify branch, remote, manifest pin, Git identity, and clean tracked state.
2. Inventory every rendering path, behavior owner, state, feature flag, resource qualifier, semantic contract, and existing test before editing.
3. Write or update the component contract and state matrix.
4. Implement through the narrowest shared semantic seam.
5. Run formatter checks, `git diff --check`, focused compilation, tests, and license checks.
6. Capture runtime screenshots, hierarchy, provenance, state evidence, and target crash/ANR scan.
7. Cover applicable light/dark, RTL, 200% font scale, landscape, large screen, input mode, reduced motion, and no-blur fallback cases.
8. Obtain independent review for every change governed by the implementation standard; review must report and resolve all Blocker and High findings before publication.
9. Report residual risk and distinguish implemented, compiled, tested, runtime-verified, and visually accepted status.

## Build baseline

```bash
cd /mnt/aosp
source build/envsetup.sh
lunch aosp_cf_x86_64_only_phone-aosp_current-userdebug
OUT_DIR=out-fluent m SystemUI -j8
```

Use `/home/azureuser/aosp-out` through `/mnt/aosp/out-fluent`. The established fast-iteration Cuttlefish serial is `127.0.0.1:6520`. Hot deployment is not release acceptance.

When a requirement is ambiguous or conflicts with Android behavior or official Fluent guidance, stop and request a decision. Do not silently weaken the standard.
