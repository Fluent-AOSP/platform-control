# Fluent AOSP implementation standard

- **Status:** Normative
- **Applies to:** every UI, theme, asset, animation, layout, and visual configuration change in Fluent AOSP
- **Audience:** human contributors, coding agents, reviewers, maintainers, and release engineers
- **Visual baseline:** Windows 11 shell and official Microsoft Fluent/WinUI guidance
- **Behavior baseline:** the pinned AOSP Android 17 source and Android platform contracts

This document defines how Fluent AOSP changes are designed, implemented, reviewed, tested, and published. It is intentionally strict. A change is not acceptable merely because it resembles Fluent in one screenshot. It must form part of a coherent system, preserve Android behavior, work across supported states and configurations, and leave reproducible evidence.

The words **MUST**, **MUST NOT**, **REQUIRED**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative.

## 1. Required reading order

Before changing a UI surface, contributors and coding agents MUST read:

1. this standard;
2. [`context.md`](../../context.md);
3. [`docs/customization-architecture.md`](../customization-architecture.md);
4. [`docs/design/fluent-material-guide.md`](fluent-material-guide.md);
5. the surface-specific specification, when one exists;
6. [`docs/test-loop.md`](../test-loop.md);
7. applicable architecture decisions in [`docs/adr/`](../adr/);
8. the owning Android 17 source and tests.

For Quick Settings, [`quick-settings-foundation.md`](quick-settings-foundation.md) is REQUIRED reading.

A contributor MUST stop and request a decision when authoritative sources or project requirements conflict. It MUST NOT silently invent a compromise.

## 2. Authority and conflict rules

### 2.1 Source hierarchy

Use sources in this order:

1. **Behavior, safety, security, and accessibility:** pinned AOSP source, Android public contracts, and existing tests.
2. **Visual language:** official Microsoft Windows 11, Fluent 2, and WinUI guidance.
3. **Project decisions:** this standard, accepted ADRs, surface specifications, and reviewed token tables.
4. **Reference captures:** licensed or privately retained Windows 11 captures used to verify composition.
5. **Designer or implementer judgment:** only where the preceding sources do not decide the issue.

Third-party mockups, memory, generated designs, and aesthetic preference are not authoritative.

### 2.2 Platform translation rule

- Android owns behavior.
- Fluent owns the intended visual language.
- The adaptation layer translates between them.

When Windows and Android conflict, preserve Android interaction, accessibility, security, privacy, navigation, and device behavior. Match Fluent as closely as possible within those constraints.

Do not port WinUI state machines, desktop window behavior, hover-only interaction, title bars, or Windows compositor APIs into Android. Do not retain a Material appearance merely because the original component used Material tokens.

### 2.3 Claims about Microsoft values

A value MUST NOT be described as “official,” “canonical,” or “Microsoft-specified” unless an official Microsoft source supports that claim. Project-derived Android translations MUST be labeled as project targets or adaptations.

## 3. Non-negotiable product invariants

| ID | Requirement |
|---|---|
| `BEH-001` | Changes MUST be UI-design changes only unless a separately approved requirement explicitly calls for behavior integration. Surfacing an existing platform-owned action through a new Fluent affordance is permitted only when the project explicitly requires that affordance; the implementation MUST delegate to the existing Android controller/setting and MUST NOT change the underlying algorithm or device behavior. Device, radio, network, audio, display, power, security, and hardware behavior MUST remain intact. |
| `BEH-002` | Existing clicks, long clicks, gestures, shade physics, predictive back, navigation, haptics, state production, ordering, editing, deep links, and policy restrictions MUST remain platform-owned. |
| `BEH-003` | Accessibility semantics, actions, traversal order, announcements, content descriptions, and focus behavior MUST be preserved or improved. Visual replacement MUST NOT replace semantic behavior. |
| `BEH-004` | A visual affordance that implies an action MUST have a real integrated action. Fake chevrons, static toggles, decorative action icons, and nonfunctional settings are prohibited. |
| `BEH-005` | Live platform state MUST remain live. Connectivity, signal, battery, volume, brightness, privacy, and policy state MUST NOT be replaced with static artwork or incomplete synthetic state. |
| `BEH-006` | Security, lockscreen privacy, redaction, admin-disabled behavior, emergency behavior, and telephony safety semantics are blockers, not visual trade-offs. |
| `BEH-007` | Settings MUST remain in their established Android categories. A “Fluent,” fork-name, custom-ROM, or catch-all settings page is prohibited. |
| `BEH-008` | Interaction targets MUST remain at least 48 dp even when the visible Fluent control is smaller. |

## 4. Visual fidelity requirements

| ID | Requirement |
|---|---|
| `VIS-001` | Windows 11 shell surfaces are the canonical visual reference. Fluent fidelity MUST be evaluated as a complete hierarchy, not as isolated colors, icons, or corner radii. |
| `VIS-002` | A surface MUST express a coherent combination of layout, density, typography, geometry, stroke, material, icon optics, state hierarchy, and motion. Applying blue and rounded corners is insufficient. |
| `VIS-003` | Use a 4 dp spacing rhythm with documented optical corrections. Alignment, baselines, and grouping MUST be deliberate. |
| `VIS-004` | Persistent controls SHOULD begin from a 4 dp radius and transient overlays from an 8 dp radius where their roles match Windows 11. Any deviation MUST be justified by Android ergonomics or an existing platform contract. |
| `VIS-005` | Do not indiscriminately cardify lists, rows, or controls. Grouping SHOULD come from spacing, alignment, tone, and hierarchy before additional containers. |
| `VIS-006` | Material-style oversized pills, floating icon wells, wallpaper-purple leakage, excessive elevation, and large empty spacing MUST be removed where they conflict with the approved Fluent composition. |
| `VIS-007` | Active, inactive, unavailable, disabled, pressed, focused, selected, loading, and error states MUST remain visually distinguishable without relying on color alone. Only implement states that the component actually supports. |
| `VIS-008` | Dark mode is the primary visual review path, but light mode is REQUIRED and MUST NOT be treated as a fallback afterthought. |
| `VIS-009` | Pixel copying is not the objective. Match visual relationships and hierarchy while adapting to Android density, insets, window classes, text scaling, and interaction bounds. |

## 5. Semantic token contract

All repeated visual decisions MUST flow through semantic aliases. Scattered literals and one-off component styling are prohibited.

Each token MUST document:

- semantic name and intent;
- official source or project rationale;
- Android source role or resource;
- light and dark values or mappings;
- active, inactive, disabled, unavailable, and contrast behavior;
- opaque/no-effect fallback;
- consuming surfaces;
- accessibility constraints;
- tests and screenshot coverage.

Use intent names such as `fluentColorContainerSelected`, `fluentStrokeControlRest`, or `fluentRadiusOverlay`. Avoid raw component names such as `qsBlue`, `settingsGray`, or `tileRoundness` unless the token is intentionally surface-specific.

Container and foreground roles MUST remain paired. Do not combine a container from one semantic role with an unrelated `on*` foreground.

View resources and Compose tokens MUST remain semantically aligned when both rendering systems implement the same surface.

## 6. Color and state

### 6.1 General policy

- Neutral hierarchy SHOULD dominate persistent surfaces.
- Brand color MUST be reserved for selected or high-emphasis state.
- Status colors MUST retain their established meaning and MUST NOT rely on hue alone.
- Wallpaper-derived color MAY remain where the surface has not received an approved fixed Fluent palette.
- A surface that stops following Monet MUST document the scope and contrast rationale.

### 6.2 Quick Settings accent contract

Quick Settings uses fixed audited accent pairs:

| Mode | Accent | Content |
|---|---|---|
| Light | `#005FB8` | white |
| Dark | `#60CDFF` | black |

These values MUST be centralized behind Quick Settings semantic roles. They MUST NOT be copied into unrelated surfaces without a separate decision.

Inactive, secondary, disabled, and stroke roles MUST use the approved neutral Fluent token layer. Do not reintroduce Material dynamic purple into the scoped Quick Settings composition.

## 7. Typography

| ID | Requirement |
|---|---|
| `TYPE-001` | Typography MUST use scalable `sp`, preserve Android font-scale behavior, and retain complete locale fallback. |
| `TYPE-002` | Match Windows 11 hierarchy through size, line height, weight, baseline, and spacing—not by embedding an unlicensed font. |
| `TYPE-003` | Segoe UI binaries MUST NOT be committed or redistributed without explicit rights. |
| `TYPE-004` | Public source MAY request the optional product-provided Android family `segoe-ui`; it MUST safely fall back when absent. |
| `TYPE-005` | Normal, Medium, and Bold weight resolution MUST be deliberate. Do not simulate medium weight accidentally through an unavailable family entry. |
| `TYPE-006` | Test 200% font scale, bold text, long English text, representative long translations, truncation, wrapping, baseline alignment, and RTL. |

Private local Segoe previews are visual evidence only. They MUST NOT become a hidden build dependency or be used to claim that a clean public build renders Segoe.

## 8. Icons and assets

| ID | Requirement |
|---|---|
| `ICON-001` | Use a curated subset of official Fluent System Icons, not wholesale icon replacement. |
| `ICON-002` | Fluent System Icons are pinned to [`microsoft/fluentui-system-icons`](https://github.com/microsoft/fluentui-system-icons) commit `956fbd8db6c77e62a046eeddb3139354229e9f23` until an explicit reviewed update. |
| `ICON-003` | Imported vectors MUST match the corresponding file under upstream `android/library/src/main/res/drawable/` at the pinned commit byte-for-byte unless a reviewed conversion is documented. Source provenance and the curated list live in `packages/SystemUI/fluent_system_icons/README.md`; the upstream MIT text lives in `packages/SystemUI/fluent_system_icons/LICENSE`; `packages/SystemUI/Android.bp` MUST include that license in generated module notices. |
| `ICON-004` | Preserve unknown, OEM, custom, and app-provided tile artwork. Do not replace artwork solely because it is not in the curated mapping. |
| `ICON-005` | Preserve live cellular and Wi-Fi rendering until a state-complete Fluent renderer exists and is tested. |
| `ICON-006` | Directional icons MUST mirror correctly in RTL. Critical Android safety metaphors MUST remain familiar. |
| `ICON-007` | Optical size, viewport, stroke weight, tint, disabled treatment, and content-description impact MUST be reviewed. |

An asset license MUST be verified independently. The Fluent System Icons MIT license does not license Segoe, product icons, illustrations, sounds, screenshots, or unrelated Microsoft assets.

## 9. Materials, blur, stroke, and depth

### 9.1 Material roles

- Use **Acrylic** intent for transient, light-dismiss Quick Settings surfaces.
- Do not call Quick Settings material Mica.
- Use solid surfaces as the required reliability and accessibility baseline.
- Use smoke only for Android modal separation where standard dismissal behavior remains intact.

### 9.2 Android implementation

| ID | Requirement |
|---|---|
| `MAT-001` | Backdrop blur MUST use Android’s compositor-owned cross-window/background blur path. `Modifier.blur` is prohibited for simulating Acrylic because it blurs content rather than the backdrop. |
| `MAT-002` | Acrylic requires tint, restrained stroke, and appropriate content contrast in addition to blur. Blur by itself is not Acrylic. |
| `MAT-003` | Every translucent implementation MUST have opaque, no-blur, reduced-transparency, unsupported-hardware, battery-saver, contrast, privacy, and performance fallbacks. |
| `MAT-004` | Persistent controls SHOULD use tone and subtle stroke before shadow. Shadows are reserved for real overlap. |
| `MAT-005` | Stacked translucent layers and double-composited icon wells are prohibited unless the design explicitly requires them and evidence proves readability. |
| `MAT-006` | Blur radius, tint, and stroke values MUST be semantic tokens and MUST be tested over more than one wallpaper. |

## 10. Motion and interaction feedback

- Preserve shade drag physics, Android gesture continuity, predictive back, haptics, and system animator-scale behavior.
- Fluent motion SHOULD be limited to local state transitions and hierarchy clarification unless a broader motion change is explicitly approved.
- State MUST remain understandable with animation disabled.
- Reduced-motion behavior is REQUIRED.
- Hover and focus states MUST be implemented for mouse, keyboard, D-pad, and accessibility input where the Android component supports them; hover MUST NOT be required to discover an action.
- Ripple or pressed feedback MAY be visually adapted but MUST retain immediate interaction confirmation.

## 11. Adaptive layout and accessibility

Every affected surface MUST be reviewed in:

- compact portrait;
- landscape;
- split screen or narrow freeform window;
- `sw600dp` or equivalent large-screen configuration;
- edge-to-edge with cutouts and navigation insets;
- RTL;
- 200% font scale;
- bold/high-contrast text where supported;
- TalkBack;
- Switch Access;
- keyboard and D-pad navigation;
- light and dark mode;
- animations enabled and disabled;
- reduced transparency/no blur;
- representative color correction and contrast settings.

A screenshot from one 360 dp dark-mode phone is never sufficient acceptance evidence.

Normal text contrast MUST be at least 4.5:1. Large text and non-text interactive visuals MUST be at least 3:1. Where Android or a safety-critical surface requires more, the stricter requirement wins.

## 12. Quick Settings composition contract

Expanded Quick Settings is the first canonical Fluent shell surface.

### 12.1 Required expanded-phone composition

- One transient Acrylic hierarchy, not a common card around all controls.
- Three compact tile columns.
- Two rows and six controls in the initial expanded phone page.
- Arbitrary user-configured tile sets, ordering, editing, and paging remain supported.
- Each tile has an individual compact Fluent surface.
- Labels sit below tile surfaces.
- Genuine secondary actions use a visually separated split target with a separator and chevron.
- A split target remains independently accessible and at least 48 dp.
- Brightness and volume are independent horizontal rail rows.
- Slider icons are sibling controls, never track decorations.
- Volume icons reflect mute, low, medium, and high state.
- The footer is visually distinct from the control body.
- The removed common Quick Settings/footer card MUST NOT be reintroduced.
- Header mobile and signal state remains platform-live.

Project targets for the 360 dp reference width are approximately 16 dp panel padding, 8–12 dp gaps, roughly 100 dp columns, and 56–60 dp visible tile surfaces over 48 dp minimum targets. These are Android project translations, not claimed Microsoft specifications.

### 12.2 Behavior preservation

Tile lifecycle, state production, click, long click, dual-target behavior, editing, pagination, accessibility, connectivity, brightness mapping, volume routing, lockscreen policy, and shade expansion remain AOSP-owned.

Auto-brightness is an explicitly approved UI integration exception under `BEH-001`: its Fluent affordance MUST invoke Android's existing platform-owned automatic-brightness mode through the established controller or setting. It MUST NOT introduce a new brightness algorithm, bypass policy, or alter sensor/display behavior. The affordance MUST be a real integrated action before its icon is considered complete; a visual-only control is prohibited.

### 12.3 Expanded and collapsed separation

Expanded and collapsed Quick Settings use different Android rendering and layout paths. Work on one MUST NOT assume the other is complete. Collapsed Quick Settings requires its own inventory, specification, tests, and visual acceptance.

## 13. Surface implementation workflow

Every change MUST follow these phases.

### Phase 0 — Establish repository state

- Confirm the owning project, branch, remote, and pinned manifest revision.
- Confirm a clean tracked worktree.
- Confirm Git author and committer identity is `Foxtrot47 <jjneutron@outlook.com>` for project-authored commits.
- Confirm the repository is an independent `Fluent-AOSP` repository, not a GitHub fork.
- Preserve complete upstream project history. Do not replace it with an orphan snapshot root.

### Phase 1 — Inventory before editing

Document:

- all rendering paths for the surface;
- behavior/state owners;
- View and Compose implementations;
- compact and large-screen resources;
- feature flags and host-specific paths;
- accessibility semantics;
- existing tests;
- runtime fallbacks;
- related assets and licenses.

Do not start with a screenshot and guess which file to change.

### Phase 2 — Write the component contract

For each component, record:

| Field | Required content |
|---|---|
| Purpose | User task and platform owner |
| Fluent reference | Official source or approved capture |
| Android behavior | State producer, events, semantics, policy |
| Visual anatomy | Container, icon, text, stroke, material, spacing |
| States | Supported state matrix |
| Adaptation | Compact, landscape, large screen, RTL, font scale |
| Fallback | Exact Android signal, feature flag, configuration, or capability check; selected opaque/no-blur/reduced-motion path; expected rendering; test setup; pass criterion |
| Tests | Unit, instrumentation, screenshot, runtime, and quantitative performance criterion where rendering cost changes |
| Licensing | Asset/font/source provenance |

### Phase 3 — Create or extend semantic seams

Prefer, in order:

1. existing resources and overlayable configuration;
2. shared semantic aliases;
3. narrow theme or Compose token adapters;
4. narrow visual rendering code;
5. behavior changes only when a separately approved functional requirement demands them.

Do not duplicate a semantic decision in multiple hosts. Shared surfaces require a shared token or renderer unless a documented host difference makes that impossible.

Each fallback claim MUST identify an observable trigger. Do not invent a universal Android “reduced transparency” setting where none exists. If the product has no direct user setting, document the actual inputs used by the implementation—for example blur capability, the existing SystemUI transparency view model, power policy, contrast mode, privacy state, feature flag, or test override. A fallback passes only when the trigger selects the documented path, content remains readable, semantics and interaction remain unchanged, protected content is not exposed, and measured frame behavior stays within the batch's reviewed budget relative to the unmodified baseline.

### Phase 4 — Implement a coherent batch

A batch SHOULD be large enough to produce a reviewable visual relationship but small enough to revert independently. Do not mix:

- visual work with unrelated refactors;
- product behavior changes with styling;
- host automation with SystemUI code;
- manifest updates with implementation commits;
- proprietary preview assets with public source.

### Phase 5 — Static and focused validation

At minimum:

- run the project formatter in check mode;
- run `git diff --check`;
- compile the narrow target;
- run affected unit/instrumentation tests;
- verify resource and asset licenses;
- verify no proprietary font or preview binary is tracked;
- review the complete diff for behavior drift.

For SystemUI iteration, use the exact output contract:

```bash
cd /mnt/aosp
source build/envsetup.sh
lunch aosp_cf_x86_64_only_phone-aosp_current-userdebug
OUT_DIR=out-fluent m SystemUI -j8
```

Hot deployment is an iteration tool only. It does not replace final product-image validation.

### Phase 6 — Runtime evidence

Use the owned Cuttlefish target at `127.0.0.1:6520` when performing the established fast iteration loop. Capture:

- relevant light and dark screenshots;
- UI hierarchy;
- exact build/source provenance;
- focused interaction/state evidence;
- target crash and ANR scan;
- fallback configuration evidence when material/effect behavior changed.

Final acceptance requires the gates in [`docs/test-loop.md`](../test-loop.md), including a product build and clean same-input runtime validation.

### Phase 7 — Independent review

Review MUST assess:

- Android behavior preservation;
- Fluent fidelity as a whole;
- accessibility and adaptive behavior;
- fallback completeness;
- asset licensing;
- tests and evidence;
- residual risk.

A reviewer MUST identify blockers explicitly. “Looks good” is not sufficient.

### Phase 8 — Commit and pin

- Use Conventional Commit subjects for new work.
- Use only `Foxtrot47 <jjneutron@outlook.com>` as author and committer for project-authored commits unless project authority explicitly changes the identity.
- Do not add automation identities, VM-derived identities, co-authors, or generated author trailers.
- Preserve full upstream history and individual Fluent commits.
- Push only after the required validation and review.
- Pin the accepted project commit in `Fluent-AOSP/android`.
- Update the exported lock in `platform-control`.
- Verify remote branch heads and manifest revisions after pushing.

## 14. Test and evidence matrix

The minimum test depth depends on the change.

| Change | Required evidence |
|---|---|
| Token-only | Token/resource tests, affected target compile, dark/light representative screenshots, diff review |
| Layout/geometry | Above plus compact, landscape, large screen, RTL, 200% font scale, hierarchy/touch-bound assertions |
| State rendering | Above plus every supported state, color-independent distinction, semantics assertions |
| Icon mapping | Asset hash/provenance, license notice, mapped and unmapped/custom cases, RTL where directional |
| Blur/material | Opaque, blur, no-blur, reduced-transparency, battery/performance/privacy fallbacks over multiple backgrounds |
| Interaction affordance | Functional action test, accessibility action, keyboard/D-pad, 48 dp target, disabled/policy cases |
| Cross-project change | Per-project tests, exact compatible manifest pin, exported lock, fresh-sync resolution |
| Release candidate | Focused tests, product build, independent review, clean identical-input Cuttlefish validation, crash/ANR evidence |

Screenshot comparison MUST include semantic assertions. Pixel similarity alone cannot establish correctness.

## 15. Prohibited implementation patterns

The following are automatic review failures unless an accepted decision explicitly permits them:

- replacing live state with static Fluent artwork;
- adding fake controls or affordances;
- changing device or hardware functionality for visual reasons;
- embedding or committing Segoe binaries without redistribution rights;
- using `Modifier.blur` as backdrop Acrylic;
- removing Android accessibility semantics to simplify layout;
- shrinking interaction bounds below 48 dp;
- hard-coding repeated colors, dimensions, or alpha values outside semantic tokens;
- pairing unrelated dynamic container and foreground roles;
- adding a common card around Quick Settings controls or footer;
- making every Settings row a card;
- adding a catch-all Fluent settings category;
- mapping every OEM/custom icon to a project icon;
- changing critical telephony colors or metaphors without safety review;
- claiming undocumented project values are official Microsoft values;
- accepting a single screenshot as complete validation;
- committing proprietary preview assets, secrets, logs, bugreports, or user data;
- using snapshot/orphan roots instead of complete upstream repository history;
- publishing with VM, `Ubuntu`, `Fluent AOSP Automation`, `Fluent AOSP Build`, or other unintended authorship.

## 16. Review severity

| Severity | Examples |
|---|---|
| Blocker | Security/privacy regression; emergency/call-state regression; broken state behavior; inaccessible action; missing full-history provenance; proprietary asset publication |
| High | Fake affordance; missing fallback; contrast failure; touch target below 48 dp; semantic role mismatch; static replacement of live state; incorrect authorship |
| Medium | Material visual leakage; duplicated tokens; missing adaptive case; avoidable direct behavior fork; incomplete evidence |
| Low | Minor optical alignment, naming, documentation, or nonblocking test clarity issue |

Blocker and High findings MUST be resolved before push or manifest pinning.

## 17. Definition of done

A change is complete only when all applicable statements are true:

- [ ] The owning Android behavior and all rendering paths were inventoried.
- [ ] The component contract and supported state matrix are documented.
- [ ] Official Fluent references or project-derived rationale are cited.
- [ ] Visual decisions use semantic tokens.
- [ ] Android behavior, security, privacy, and accessibility remain intact.
- [ ] Light, dark, RTL, font scale, adaptive layout, and input-mode requirements pass.
- [ ] Opaque, no-blur, reduced-motion, and effect fallbacks pass where applicable.
- [ ] Asset/font licensing and notices are complete.
- [ ] Focused formatting, compile, tests, and `git diff --check` pass.
- [ ] Runtime screenshots, hierarchy, provenance, and crash/ANR evidence exist.
- [ ] Independent review has no unresolved Blocker or High finding.
- [ ] Project-authored commits use the required Foxtrot47 identity.
- [ ] Full upstream history and individual Fluent commits are preserved.
- [ ] The project branch, authoritative manifest, and exported control lock pin the accepted revisions.

If an item is not applicable, the change record MUST say why. It MUST NOT simply omit the item.

## 18. Agent response contract

A coding agent working on Fluent AOSP MUST report:

1. requirements and IDs being implemented;
2. files and rendering paths inspected;
3. Android behavior explicitly preserved;
4. Fluent references and project-derived values used;
5. files changed;
6. commands and tests run;
7. runtime evidence paths;
8. accessibility/adaptive/fallback coverage;
9. licensing impact;
10. commit and remote revisions, when publishing was authorized;
11. residual risks and deferred requirements.

An agent MUST distinguish **implemented**, **compiled**, **tested**, **runtime-verified**, and **visually accepted**. These terms are not interchangeable.

## 19. Official references

- [Fluent 2 design principles](https://fluent2.microsoft.design/design-principles)
- [Fluent 2 design tokens](https://fluent2.microsoft.design/design-tokens)
- [Fluent 2 color](https://fluent2.microsoft.design/color)
- [Fluent 2 typography](https://fluent2.microsoft.design/typography)
- [Fluent 2 layout](https://fluent2.microsoft.design/layout)
- [Fluent 2 iconography](https://fluent2.microsoft.design/iconography)
- [Fluent 2 accessibility](https://fluent2.microsoft.design/accessibility)
- [Windows 11 geometry](https://learn.microsoft.com/windows/apps/design/signature-experiences/geometry)
- [Windows materials](https://learn.microsoft.com/windows/apps/design/signature-experiences/materials)
- [Windows Acrylic](https://learn.microsoft.com/windows/apps/design/style/acrylic)
- [Windows Mica](https://learn.microsoft.com/windows/apps/design/style/mica)
- [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility)
- [Android adaptive layouts](https://developer.android.com/design/ui/mobile/guides/layout-and-content/adapt-layout)
- [AOSP dynamic color](https://source.android.com/docs/core/display/dynamic-color)
- [AOSP connectivity UI](https://source.android.com/docs/core/connect/connectivity-ui)
