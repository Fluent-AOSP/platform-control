# Quick Settings visual foundation

## Scope

> **Normative policy:** all new work follows the [Fluent AOSP implementation standard](fluent-implementation-standard.md). The validation sections below retain snapshot-era source IDs as historical evidence. After the full-history/authorship migration, their equivalent full-history commits are the `Historical local commit` IDs shown in each batch; the current Fluent branch head is `9f0e6acdc0353da1b32b7868378e7c4908779d4a`.

M4 starts at the shared Android 17 Compose renderer. The first three batches established semantic tile, layout, and chrome seams; the fourth used those seams for a cohesive Windows 11-aligned composition; the fifth added a scoped Windows-blue and cool-neutral color/material system; the sixth extends that system to the panel and brightness control. The work does not change tile state production, layout count, touch targets, clicks, long-clicks, slider behavior, accessibility semantics, connectivity behavior, or lockscreen policy.

Windows 11 Quick Settings is the canonical visual reference. The Android implementation should be recognizably similar as a complete system—compact control geometry, flat split controls, restrained strokes, dense spacing, overlay materials, typography proportions, and motion—while retaining Android gestures, state production, security, accessibility, and adaptive layout.

## Current full-history head status

Current published source: `9f0e6acdc0353da1b32b7868378e7c4908779d4a`.

Status terms are intentionally separate:

- **Implemented/published:** expanded composition, curated icons, scoped optional Segoe family, Acrylic roles, split controls, brightness/volume rails, and mute/level volume artwork are present in the published source.
- **Compiled:** an exact-head `OUT_DIR=out-fluent m SystemUI -j8` completed successfully during the publication session. No standalone build-log artifact was retained, so this is an attested compile rather than archived build evidence.
- **Runtime-smoke verified:** the exact public-source APK was hot-deployed after provisioning the optional font only on the private test device. The dark expanded screenshot is `/home/azureuser/android-test-artifacts/fast-iteration-cvd/cycle-pushed-device-segoe-18-dark/quick-settings-expanded-dark.png`; its targeted failure scan is empty at `failure-signals.txt` in the same directory.
- **Reviewed:** the final license and medium-weight fixes received independent review with no remaining Blocker or High finding. This review did not replace full SystemUI test or product validation.
- **Not yet finally accepted:** focused exact-head tests, product build, full adaptive/accessibility/fallback matrix, clean same-input Cuttlefish pair, and fresh-checkout validation remain required.

Earlier batch evidence below remains valid historical evidence for the tree states it records; it MUST NOT be represented as final acceptance of the current head.

## Approved project flyout composition

Official Windows 11 and Fluent guidance is authoritative. The supplied third-party Windows-like reference at `https://www.pasteboard.co/xiyHrUnntRgT.png` is supporting composition evidence only: its Windows build, capture provenance, and redistribution rights are not established. The resolved 466×560 PNG has SHA-256 `abdf6956b72f6a4a19c461b9cc648b0a6f7d9b1d80b07ed887748eeacddf18e1`; a verification copy is retained outside Git at `/home/azureuser/android-test-artifacts/design-references/windows11-quick-settings-xiyHrUnntRgT.png`. It is not redistributed publicly pending licensing review and MUST NOT be used alone to claim an official Microsoft value.

The project approves the following structural relationships as Android adaptation requirements, based on official Fluent principles and corroborated by the reference:

- One floating, dark Acrylic-like flyout with a distinct footer band, rather than a collection of large Android cards filling the entire shade.
- The canonical initial visible arrangement shows six controls in a three-column by two-row grid. Each control has a compact rectangular icon surface with its text label below the surface, not inside a wide two-column tile. Android's arbitrary user-configured tile set, paging, ordering, and edit operations remain supported beyond that initial viewport.
- Bright cyan active surfaces with dark content; inactive surfaces are quiet charcoal layers with light content and restrained borders.
- Optional chevrons are compact trailing affordances inside split controls such as Wi-Fi and Accessibility.
- Brightness and volume are independent horizontal rail rows: leading icon, thin cyan/neutral track, compact circular thumb, and an optional trailing disclosure affordance. The red rectangle in the supplied image is an annotation around brightness, not part of the Windows UI.
- Battery status sits at the left of the footer while edit and settings actions sit at the right. The footer is separated from the control body by material and tone, not by oversized standalone Android buttons.
- System clock and status information remain outside the flyout. On Android they may remain in the platform-owned shade header, but must not dominate or visually merge with the Fluent control panel.

On the 360 dp reference phone width, the Android translation should target roughly 16 dp panel padding, 8–12 dp column gaps, three approximately 100 dp tile columns, 56–60 dp visible tile surfaces, and 48 dp minimum interaction bounds. Labels may wrap or ellipsize according to Android locale and font-scale rules. Android continues to own tile state, long press, editing, brightness semantics, insets, lockscreen privacy, and accessibility.

## Android 17 implementation inventory

| Surface | Primary implementation |
|---|---|
| Compatibility shade host | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/composefragment/QSFragmentCompose.kt` |
| Scene-container shade host | `frameworks/base/packages/SystemUI/compose/features/src/com/android/systemui/shade/ui/composable/ShadeScene.kt` |
| Collapsed tiles | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/QuickQuickSettings.kt` |
| Expanded grid | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/TileGrid.kt` |
| Tile surface and state colors | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt` |
| Shared tile content and dimensions | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/CommonTile.kt` |
| Brightness container and focus outline | `frameworks/base/packages/SystemUI/src/com/android/systemui/brightness/ui/compose/BrightnessSlider.kt` |
| Edit-grid chrome | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/EditTile.kt` |
| Scene-container toolbar chrome | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/toolbar/` |
| Compatibility/scene footer actions | `frameworks/base/packages/SystemUI/compose/features/src/com/android/systemui/qs/footer/ui/compose/FooterActions.kt` |
| Platform-to-Compose state adapter | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/viewmodel/TileUiState.kt` |
| Compact-phone dimensions | `frameworks/base/packages/SystemUI/res/values/shade_dimens.xml` |
| Large/desktop dimensions | `frameworks/base/packages/SystemUI/res/values-sw600dp/shade_dimens.xml` |
| Tile behavior tests | `frameworks/base/packages/SystemUI/tests/src/com/android/systemui/qs/panels/ui/compose/TileTest.kt` |
| State/accessibility tests | `frameworks/base/packages/SystemUI/multivalentTests/src/com/android/systemui/qs/panels/ui/viewmodel/TileUiStateTest.kt` |

Both shade architectures use the shared panel renderer, so host-specific XML or scene-only styling would diverge. The resource-backed shape seam in `CommonTile` is the narrowest shared integration point.

## Semantic token matrix

### First implementation

| Semantic token | Compact upstream | Compact target | Large upstream | Large target | Intent |
|---|---:|---:|---:|---:|---|
| Active icon radius | 16 dp | 12 dp | 12 dp | 10 dp | Rounded-square active icon well |
| Inactive icon radius | 50 dp | 16 dp | 22 dp | 14 dp | Replace circle/pill geometry without removing state distinction |
| Active tile radius | 24 dp | 16 dp | 18 dp | 14 dp | Fluent-inspired rounded tile surface |
| Inactive tile radius | 50 dp | 20 dp | 28 dp | 18 dp | Subtle animated shape cue remains |

Existing `common_tile_default_*` resources become aliases to new component-semantic `qs_shape_*` resources. This keeps current tile consumers stable while making the fork’s visual contract explicit. The Quick Settings tooltip receives a dedicated `qs_tooltip_corner_radius` token at its original 16 dp compact/12 dp desktop values so the tile-only change does not alter transient-surface geometry.

### Second implementation batch

| Semantic token | Compact upstream | Compact target | Large upstream | Large target | Intent |
|---|---:|---:|---:|---:|---|
| Icon-only tile glyph | 32 dp | 28 dp | 24 dp effective | 24 dp | Reduce visual weight without shrinking the tile target |
| Labeled tile glyph | 28 dp | 24 dp | 20 dp effective | 20 dp | Improve icon/label hierarchy and text room |
| Icon-to-label spacing | 6 dp | 8 dp | 6 dp | 6 dp | Establish compact 8 dp rhythm while preserving desktop density |
| Start padding | 8 dp | 8 dp | 6 dp | 6 dp | Semantic alias; no geometry change |
| Regular end padding | 12 dp | 12 dp | 12 dp | 12 dp | Semantic alias; no geometry change |
| Dual-target end padding | 8 dp | 8 dp | 8 dp | 8 dp | Semantic alias; no geometry change |

Normal tiles and resize-mode edit tiles share the new content-spacing token. Inter-tile edit-grid spacing remains an independent 6 dp value, avoiding drag-geometry changes. Direct semantic icon resources replace the previous desktop runtime inversion while preserving its effective 24/20 dp result.

### Third implementation batch

| Semantic token | Compact upstream | Compact target | Large upstream | Large target | Intent |
|---|---:|---:|---:|---:|---|
| Shade panel radius | 46 dp | 28 dp | 36 dp | 24 dp | Reduce the oversized panel arc |
| Brightness container radius | 24 dp | 16 dp | 24 dp inherited | 12 dp | Replace pill treatment while retaining the track and thumb |
| Edit-grid container radius | 28 dp | 20 dp | 28 dp inherited | 16 dp | Bring current/available tile containers into the shared hierarchy |
| Toolbar protected background radius | circle | 10 dp | circle | 8 dp | Rounded-square decorative protection without changing button interaction geometry |
| Toolbar feedback radius | pill | 10 dp | pill | 8 dp | Align transient non-interactive feedback with compact chrome |

The brightness focus outline now uses the same corner token and horizontal/vertical frame expansion as the background it surrounds. Toolbar button hit targets, semantics, and click behavior remain unchanged. Compact and `sw600dp` values use parallel feature-flag-qualified aliases.

### Fourth implementation batch: initial Windows alignment (visually superseded)

This batch superseded the earlier exploratory radii while retaining their semantic resource seams. Later comparison with the canonical flyout reference showed that it changed tokens without sufficiently changing the Material/Android composition; it remains historical implementation evidence, not the final visual target.

| Surface/token | Previous compact | Windows-aligned target | Contract |
|---|---:|---:|---|
| Tile and split-target radius | 16–20 dp | 4 dp | Windows persistent-control geometry; state moves to fill/stroke rather than shape |
| Panel/edit overlay radius | 20–28 dp | 8 dp | Windows flyout/overlay geometry |
| Compact panel gutter | 0 dp | 12 dp | Windows small-window gutter where the Android shade host permits floating layout |
| Tile height | 72 dp | 56 dp | Denser Windows-like composition while remaining above 48 dp |
| Split toggle target | 56 dp | 48 dp | Retain Android minimum target |
| Tile glyphs | 24/28 dp | 20 dp | Windows system-control icon optics |
| Brightness visual track/thumb | 40/52 dp | 32/48 dp | Compact bar treatment with a 48 dp interaction dimension |
| Toolbar visual/icon/target | 36/24/48 dp | 32/20/48 dp | Small visible action with full Android target |
| Tooltip/control/overlay radius | 16/varied/20+ dp | 4/4/8 dp | Consistent Windows geometry hierarchy |

Active split tiles now use one full accent surface rather than a Material-style colored icon well. Inactive and unavailable split targets use transparent icon backgrounds so translucent surfaces are not composited twice; subtle strokes preserve state without restoring a separate well. Primary labels remain 14/20 semibold and secondary labels use the 12/16 regular body role, matching the Windows type ramp without redistributing Segoe. Edit actions, menus, power controls, and toolbar focus shapes follow the same 4/8 dp hierarchy. The compatibility host's independently rendered footer uses the same rounded rectangles, strokes, 20 dp icons, and 14/20 text while retaining 48 dp effective targets. All visible sizes remain separate from interaction and semantic bounds.

### Fifth implementation batch: Windows color and Acrylic-like layers

The Quick Settings roots now install one scoped color scheme across compatibility, scene, and overlay hosts. Active controls use Windows-blue role pairs: `#005FB8` with white content in light mode (6.31:1 contrast) and `#60CDFF` with black content in dark mode (11.67:1). Inactive, unavailable, edit, toolbar, footer, and slider surfaces consume cool neutral semantic container/stroke roles instead of wallpaper-purple Material tones. Tooltips use neutral light/dark role pairs rather than the prior tertiary purple.

When the platform shade-blur feature is available, inactive control layers are translucent so the platform-owned blurred shade remains visible beneath them. When it is unavailable, the same semantic roles resolve to explicit opaque light/dark fills; the forced-dark compatibility path derives its palette from the enclosing platform theme rather than the device's unforced resource configuration. This approximates Acrylic intent without claiming Windows compositor behavior or weakening Android privacy/performance fallbacks.

The color override is limited to Quick Settings theme roots. The shared brightness implementation retains its upstream defaults for the standalone Settings brightness dialog; each Quick Settings host explicitly injects its Fluent slider colors. State production, disabled alpha semantics, click handling, editing, brightness behavior, and accessibility remain platform-owned.

### Sixth implementation batch: panel material and brightness control

The compatibility, scene, and overlay roots now share a cool `#CCF3F3F3` light / `#CC202020` dark panel tint when platform transparency is active. Scene and overlay hosts select the opaque semantic surface when their runtime view models report that transparency is unavailable; the compatibility tint composes over the platform-owned shade fallback. This extends the Acrylic-like hierarchy from individual controls to the Quick Settings panel without changing Android blur ownership or privacy/performance decisions.

Quick Settings brightness now uses a 4 dp rounded line, a compact 20 dp thumb, and the existing 20 dp state icon inside a 32 dp visual track slot. Compose retains a directly tested 48 dp slider target. The custom track mirrors its active segment in RTL and derives the icon-color transition from the measured track width rather than a fixed threshold. Gamma mapping, value animation, drag/stop callbacks, haptics, falsing, policy restrictions, app-override warnings, brightness mirroring, semantics, and the standalone Settings brightness appearance remain unchanged.

### Preserved Android tokens

| Concern | Preserved source |
|---|---|
| Active color | Scoped `fluent_qs_accent_*` / `fluent_qs_on_accent_*` role pairs |
| Inactive surfaces | Scoped translucent/opaque `surfaceContainer*` mappings selected by blur availability |
| Unavailable state | Existing surface/on-surface-variant alpha treatment |
| Typography scaling/fallback | Platform scalable `titleSmallEmphasized` and `bodySmall` roles |
| Tile height | 56 dp compact and large-screen |
| Toggle target | 48 dp compact and large-screen |
| State and accessibility | `QSTile.State` to `TileUiState` conversion |
| Tooltip shape | Dedicated 4 dp persistent-control token |

The fixed brand values are centralized as named resources rather than scattered literals. Android still owns light/dark mode, foreground text roles, unavailable-state semantics, high-level shade blur, and fallback behavior. The deliberate fixed accent means Quick Settings no longer follows wallpaper hue for active controls; that trade-off was selected to produce a clearly Windows-like identity.

## Baseline and current reference

The stock locally built Android 17 baseline is tracked at:

- `docs/baselines/quick-settings/android17-stock-compact.png`
- Display: 720 × 1280
- Runtime: same-build Cuttlefish
- Fingerprint: `generic/aosp_cf_x86_64_only_phone/vsoc_x86_64_only:17/CP2A.260605.016/eng.azureu:userdebug/test-keys`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T053445Z`
- Image SHA-256: `937aeb896c72497073e6bfbe44efde87ed9c0fd1572c4a50e35e918c94ea8b1c`

The first shape-token reference is tracked at:

- `docs/baselines/quick-settings/android17-fluent-shapes-compact.png`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T065627Z`
- Image SHA-256: `84f4ccba02f33516eea0fc1be56b2d1ddf0ad653eb4300ac7788301f30e240aa`

The shape-plus-layout reference is tracked at:

- `docs/baselines/quick-settings/android17-fluent-layout-compact.png`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T081409Z`
- Image SHA-256: `771699448567bc41c32e83f3474dfb5d165dea2767afc617eb7f778a33009a37`

The expanded shape-plus-chrome reference is tracked at:

- `docs/baselines/quick-settings/android17-fluent-chrome-expanded.png`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T093416Z`
- Image SHA-256: `b1b7ca5b2821627bb0b22d8f3dbd816a22ecf6011cbf8dfafbb5313e40d85a3a`

The intermediate Windows-token expanded reference is tracked at:

- `docs/baselines/quick-settings/android17-windows11-fluent-expanded.png`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T105905Z`
- Image SHA-256: `f2aae20579b5b5f6e54ffd99faf038e03e8a7a03d6f85551770d87d09ac83a04`

The Windows-blue and control-layer reference is tracked at:

- `docs/baselines/quick-settings/android17-windows11-fluent-colors-expanded.png`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T115229Z`
- Image SHA-256: `3b273040401055db41cac29b0d57d8abd048656ab1f966c54265fd1185c3dc67`

The latest technically accepted, but visually superseded, panel and thin-brightness reference is tracked at:

- `docs/baselines/quick-settings/android17-windows11-fluent-panel-brightness-expanded.png`
- Source evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T153553Z`
- Image SHA-256: `0d124501add20407fc1f6aa0466b3e20b08162ac8c9193b6fb735d4cb23e546a`

The compact images contain active Bluetooth/mobile data, inactive Wi-Fi, and unavailable Cast in one test-owned frame. The expanded references additionally prove the resource-backed brightness control, full Quick Settings hierarchy, and host-specific footer while retaining platform-owned state behavior and controls.

## Validation contract

1. Build focused `SystemUI` and `SystemUITests` targets.
2. Run the existing tile behavior and state/accessibility test classes.
3. Rebuild product images incrementally.
4. Run two clean Cuttlefish boots from the modified image.
5. Require distinct home, first-pull, and fully expanded Quick Settings images; SystemUI container and brightness-slider hierarchy markers; clean target crash/ANR classification; complete evidence; graceful stop; and no lingering transport.
6. Compare the modified screenshot with the stock baseline and confirm all representative states remain distinguishable.

## First-slice validation

- Historical local commit: `7a6ec03afcd84148e966a65eba74330967d012f2`
- Published source commit: `2d914f3d467f371987f7171805716ef78504d7dd`
- Published repository: `https://github.com/Fluent-AOSP/platform_frameworks_base`
- Snapshot upstream: `94b4c163b7dfe5ce3607f7bb8456f9573f7de57d`
- Focused targets: `SystemUI` and `SystemUITests` passed.
- On-device focused evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T070528Z`
- Focused result: 41 passed, 0 failed across token, tile interaction, state, policy, and accessibility-role tests.
- Incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T065403Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T071022Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T071420Z`

Both accepted runs passed the SystemUI hierarchy and screenshot gates, target crash/ANR scan, bugreport collection, same-build graceful stop, and post-stop transport/process checks. Their source manifests and complete product-image checksum sets are identical.

## Second-batch validation

- Historical local commit: `a25ecd17bfee2711fc3194d396d4de6f225632df`
- Historical parent: `7a6ec03afcd84148e966a65eba74330967d012f2`
- Published source commit: `62ec7bd5e5da3b3df0af7de9e119ddd6a5a2c6b0`
- Published repository: `https://github.com/Fluent-AOSP/platform_frameworks_base`
- Focused evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T080219Z`
- Focused result: 57 discovered, 48 passed, 9 upstream configuration assumptions, 0 failed. This includes token aliases and values, tile interaction, edit-mode operations, state/accessibility mapping, and overlay tests.
- Incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T080649Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T081409Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T081829Z`

The first launch after product packaging normalized the generated `super.img` and `userdata.img`; component partition images were unchanged. The accepted pair was captured after that one-time normalization and has identical source manifests and complete product-image checksum sets. Both runs passed all runtime, evidence, crash/ANR, and clean-stop gates.

## Third-batch validation

- Historical local commit: `9f67040d68f04f1dec7c347134fc7a18a2a232a7`
- Historical parent: `a25ecd17bfee2711fc3194d396d4de6f225632df`
- Published source commit: `b03b7af66051e6de8fb4c7cbeda8e13ade27bf3b`
- Published repository: `https://github.com/Fluent-AOSP/platform_frameworks_base`
- Focused evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T085703Z`
- Focused result: 60 discovered, 50 passed, 10 configuration assumptions, 0 failed. One diagnostic wide-resource test was skipped because this product optimizes the desktop-sizing flag; it was removed before commit rather than retained as a non-executing test. The production code and remaining compact tests compiled in that run, and the final committed source compiled again in the product build.
- Incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T091358Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T092107Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T092512Z`
- Accepted source-manifest SHA-256: `ee69d167f4878b883a12f048dc903646c371a5b626ef29de2264d92f91df9309`
- Accepted product-checksum-list SHA-256: `347d3a275988425d78eb7e5242f6bf816954983ecce176b3a6a91b9c04729a4a`
- Expanded-Quick-Settings gate evidence: `/home/azureuser/android-test-artifacts/cuttlefish-20260812T093416Z`

The packaging launch again normalized only generated `super.img` and `userdata.img`; component partitions were unchanged. The accepted pair then used byte-identical source manifests and complete image checksum lists. Both pair members, plus the expanded-view gate run, passed UI, crash/ANR, bugreport, graceful-stop, and post-stop cleanliness checks.

## Fourth-batch validation

- Historical local commit: `e2210836149cee234211a39dc44e866bf0219650`
- Historical parent: `9f67040d68f04f1dec7c347134fc7a18a2a232a7`
- Published source commit: `3efdf35cd4b7554905d10e7100f0d75a4ad98b09`
- Published repository: `https://github.com/Fluent-AOSP/platform_frameworks_base`
- Focused test evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T100601Z`
- Focused result: 87 discovered, 78 passed, 9 upstream configuration assumptions, 0 failed. This covered compact/large tokens, shared tile behavior and accessibility, edit mode, and shade overlay composition.
- Final corrected-source compile: `/home/azureuser/android-test-artifacts/systemui-fluent-final-build-20260812T103333Z` (`SystemUI` and `SystemUITests`, commit `e2210836149c`).
- Final incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T104701Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T105446Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T105905Z`
- Accepted source-manifest SHA-256: `b000f1b5c93786e33edea7884b7b92b32f85456b2ee260c4dd1b201f2154b431`
- Accepted product-checksum-list SHA-256: `dd5351e31f6da35fe0a814381ff669c8d2323cce9933a87986ff7446006ce473`

The first final-image launch exposed and corrected double-composited translucent icon wells and a host-specific Material footer path; that candidate image and build are superseded. The final packaging launch normalized only generated `super.img` and `userdata.img`, with every component partition unchanged. Runs two and three then used byte-identical complete inputs and both passed home, first-pull, expanded hierarchy/screenshot, crash/ANR, bugreport, graceful-stop, listener/process, and ADB cleanup gates. The verified expanded frame was delivered through the private Telegram channel as message 44.

## Fifth-batch validation

- Historical local commit: `9f104c3c949e777bebe6f9f57da0d9667f7f055a`
- Historical parent: `e2210836149cee234211a39dc44e866bf0219650`
- Published source commit: `241dabaf81350d3912279c8424f64cec99e6b82f`
- Published repository: `https://github.com/Fluent-AOSP/platform_frameworks_base`
- Focused compile evidence: `/home/azureuser/android-test-artifacts/systemui-fluent-colors-build-20260812T112213Z`
- Focused on-device evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T113734Z`
- Focused result: 88 discovered, 79 passed, 9 upstream configuration assumptions, 0 failed.
- Incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T114308Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T114817Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T115229Z`
- Accepted source-manifest SHA-256: `c8f8610dcf1f844be1b7d916e60f4d5ec2b3b4ec92b4cb0fee4ad96665fa9966`
- Accepted product-checksum-list SHA-256: `c528123388a246efac5e1306fbe57f038ddbce2bbb2c021d0b5c8b29a2340ff9`

Independent final review reported no blockers. The first post-build launch normalized only generated `super.img` and `userdata.img`; it was also rejected because the second automation gesture remained at the valid first-pull view instead of reaching the expanded brightness/footer gate. The next two runs used byte-identical complete inputs and passed all UI, crash/ANR, bugreport, graceful-stop, process/listener, and ADB cleanup gates. The final verified expanded frame was delivered through the private Telegram channel as message 50.

## Sixth-batch validation

- Historical local commit: `b8d800b4bae9c68907c1b4e3c12c4968af60ff1a`
- Historical parent: `9f104c3c949e777bebe6f9f57da0d9667f7f055a`
- Published source commit: `e40e612abb235e0057ec06931b5650503adc4c1f`
- Published repository: `https://github.com/Fluent-AOSP/platform_frameworks_base`
- Final corrected-source compile: `/home/azureuser/android-test-artifacts/systemui-fluent-panel-slider-final-build-20260812T150755Z`
- Focused on-device evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T152127Z`
- Focused result: 93 discovered, 84 passed, 9 upstream configuration assumptions, 0 failed. The passing brightness test directly verifies the 48 dp Fluent slider target.
- Final incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T152556Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T153201Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T153553Z`
- Accepted source-manifest SHA-256: `b3150310ff73d05c471e7e24d0d6f6e387bf213d74aab92e6afb6ea38792ac76`
- Accepted product-checksum-list SHA-256: `88cae2bdc138b55d327637d637bfc4bb98a5bfa3d22b11f83c08bd540a2895c5`

Independent review found no blocker after the runtime no-blur fallback and measured icon-threshold fixes. The first visible candidate exposed that the cached draw layer did not repaint the asynchronously loaded brightness icon; the final source renders the icon as a Compose child and supersedes that candidate build. The first launch of the final image normalized only generated `super.img` and `userdata.img`. The accepted pair then used byte-identical source manifests and complete image checksum lists, with both runs reporting `PASS`, `CLEAN`, and `expanded=true`. The representative expanded frame was delivered through the private Telegram channel as message 57.

## Batched follow-up work

Acrylic readability/performance coverage, detailed views, motion, large-screen runtime coverage, and configuration work will be grouped into materially larger coherent batches. Each batch uses focused build/test work while editing, followed by one final incremental product build and runtime validation. This avoids rebuilding product images after individual token changes while retaining the milestone evidence gates.
