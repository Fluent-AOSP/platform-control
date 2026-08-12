# Execution plan

The project advances only when the preceding gate has repeatable evidence.

1. **Foundation (complete)**
   - Record the upstream and manifest policy.
   - Maintain host preflight, build, and smoke-test scripts.
   - Export a revision-locked Repo manifest after the first successful sync.
2. **Baseline AOSP build (complete)**
   - Sync the pinned `Fluent-AOSP/android` manifest; unchanged projects resolve to Android Gitiles and modified projects resolve to independent Fluent repositories.
   - Build `aosp_cf_x86_64_only_phone-aosp_current-userdebug`.
   - Archive manifest, build fingerprint, image hashes, logs, and tool versions.
3. **Built-image closed loop (complete)**
   - Boot the locally built image in Cuttlefish using host tools from the same build.
   - Prove bounded boot, explicit ADB targeting, screenshots, UI hierarchy, logcat, bugreport, crash/ANR classification, and clean shutdown.
   - The first clean passing Cuttlefish run may request design feedback with the raw test-owned Quick Settings baseline; require a second consecutive clean run to complete the gate. Low-noise sync/build/verification status hooks may use the separately configured channel; credentials remain outside Git.
4. **Quick Settings structural pilot**
   - Inventory the Android 17 SystemUI implementation before selecting edit points.
   - Translate the canonical Windows 11 flyout into a floating Android panel with three compact tile columns, labels below tile surfaces, independent slider rails, and a distinct footer.
   - Add semantic Fluent roles beneath that composition and preserve representative inactive, active, unavailable, split-target, and transient states without changing tile behavior.
   - Validate dynamic color, light/dark/contrast, TalkBack, 48 dp targets, RTL, font scale, landscape, lockscreen privacy, and frame performance.
5. **SystemUI expansion**
   - Extend only validated tokens and patterns to shade/media/related surfaces.
   - Blur remains an optional experiment with an opaque fallback, never a baseline dependency.
6. **Settings**
   - Apply shared tokens to native preference components.
   - Keep search, deep links, category ownership, summaries, admin states, and adaptive behavior intact.
   - Put each customization in its relevant existing category; no “Fluent,” fork-name, or OS-specific dumping-ground menu.
7. **Dialer and other apps**
   - Theme noncritical UI after defining a telephony safety test plan.
   - Preserve emergency, DTMF, answer/decline/end-call, proximity, and permissions semantics.
8. **Release hardening**
   - Pin inputs and artifacts, run compatibility/accessibility/performance matrices, generate notices/SBOM, and complete trademark/licensing review.

See `ROADMAP.md` for milestones and exit criteria.
