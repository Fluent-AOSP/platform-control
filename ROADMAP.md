# Roadmap

## M0 — Control-plane foundation

**Status:** Complete. Foundation commit: `51f4d64`.

**Deliverables:** approved baseline ADR, design terminology, host record, test-loop contract, customization architecture, safe scripts, task entry points.

**Exit:** repository validation passes; foundation commit is reviewable and contains no generated runtime artifacts other than the intentionally tracked source lock.

## M1 — Pinned AOSP baseline

**Status:** Complete. The normalized lock contains 1,084 projects pinned to full revisions.

**Deliverables:** synced `android17-release`, reviewed `repo manifest -r` lock file, recorded Repo/tool versions.

**Exit:** the lock resolves every project to a revision; an intentional update procedure is documented in the lock-file review.

## M2 — Initial product build

**Status:** Complete. Accepted evidence: `/home/azureuser/android-test-artifacts/aosp-build-20260812T045000Z`.

**Deliverables:** `aosp_cf_x86_64_only_phone-aosp_current-userdebug` images and same-build host tools; build log, manifest, fingerprints, and checksums.

**Exit:** build succeeds from the locked manifest without undocumented source drift. Modified projects are published as normal commits in independent `Fluent-AOSP` repositories and pinned by exact project commit IDs inside the separately pinned manifest.

## M3 — Locally built Cuttlefish loop

**Status:** Complete. Consecutive accepted evidence:

- `/home/azureuser/android-test-artifacts/cuttlefish-20260812T053100Z`
- `/home/azureuser/android-test-artifacts/cuttlefish-20260812T053445Z`

Both runs used identical locked manifests and product-image checksum sets, passed the SystemUI semantic/visual gate and crash/ANR scan, collected bugreports, stopped cleanly, and left no process, listener, or ADB transport.

**Deliverables:** bounded headless boot, explicit ADB serial, home and Quick Settings screenshots, UI hierarchy, all-buffer logcat, bugreport, crash/ANR scan, and clean owned-instance stop.

**Exit:** two clean consecutive runs produce required core evidence and a successful owned-instance stop; a bounded bugreport timeout or explicit disable is recorded rather than hidden. The first clean passing Cuttlefish run may send the raw test-owned design-feedback screenshot, while the second clean run completes M3. Low-noise status notifications may operate earlier. Credentials remain outside Git.

## M4 — Quick Settings foundation

**Status:** In progress. The full-history `Fluent-AOSP/platform_frameworks_base` branch publishes the expanded and phone-collapsed Fluent Quick Settings implementations through commit `30634ab7b946`. Expanded QS provides three compact tile columns, six initial controls per phone page, labels below individual tile surfaces, independent brightness and volume rails, Fluent split-control treatment, a distinct footer, scoped Acrylic roles/fallbacks, curated Fluent icons, and optional product-provided Segoe resolution. Collapsed phone QS presents the first four controls in user order as individual one-column Fluent surfaces on a unified Acrylic shade; landscape, `sw600dp`, protected, flag-disabled, and runtime no-blur states retain platform topology or opaque scrims. Exact-head `SystemUI` compilation, hot-deployed runtime fallback/configuration checks, crash/ANR scans, and independent review passed, but this is not final acceptance: focused tests, product-image validation, the complete adaptive/accessibility matrix, and clean same-input Cuttlefish validation remain pending. Broader RTL, font-scale, landscape, `sw600dp`, reduced-transparency, disabled-state, and accessibility evidence is still required. The approved auto-brightness affordance must delegate to Android's existing automatic-brightness mode and must not change brightness algorithms or device behavior.

**Deliverables:** Android 17 code inventory, semantic token matrix, representative tile states, screenshot baselines, accessibility and behavior checks.

**Exit:** inactive/active/unavailable states remain semantically correct across light/dark/dynamic/contrast themes; no regression in gestures, long-press, connectivity, TalkBack, 48 dp targets, RTL, or lockscreen privacy.

## M5 — Quick Settings refinement

**Deliverables:** hierarchy, shape, icons, spacing, motion, and transient-surface treatment; performance measurements and opaque/reduced-motion fallbacks.

**Exit:** stable frame behavior and accessibility on the reference virtual device; any blur experiment is separately gated and removable.

## M6 — Settings

**Deliverables:** shared token adoption in native preference components and adaptive layouts.

**Exit:** search, deep links, summaries, admin-disabled states, category ownership, and accessibility remain intact. No OS-specific catch-all menu exists.

## M7 — Dialer and selected platform apps

**Deliverables:** scoped visual adaptations and an explicit telephony safety test plan.

**Exit:** emergency, DTMF, call-state, proximity, answer/decline/end, permissions, and accessibility checks pass. Cuttlefish UI testing is not treated as proof of carrier/IMS behavior.

## M8 — Release hardening

**Deliverables:** regression matrix, update/rebase procedure, SBOM/notices, licensing/trademark review, reproducible inputs, and signed release policy.

**Exit:** all review findings are dispositioned and release authority explicitly approves publication.
