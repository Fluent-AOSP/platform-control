# Quick Settings visual foundation

## Scope

M4 starts at the shared Android 17 Compose tile renderer. The first two changes are limited to shape and layout tokens. They do not change tile state production, color roles, icon assets, typography, layout count, touch targets, clicks, long-clicks, accessibility semantics, connectivity behavior, or lockscreen policy.

The design goal is a Fluent-inspired hierarchy adapted to Android: softly rounded rectangles with a subtle state-dependent radius change, not a literal WinUI surface and not fixed Windows colors.

## Android 17 implementation inventory

| Surface | Primary implementation |
|---|---|
| Compatibility shade host | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/composefragment/QSFragmentCompose.kt` |
| Scene-container shade host | `frameworks/base/packages/SystemUI/compose/features/src/com/android/systemui/shade/ui/composable/ShadeScene.kt` |
| Collapsed tiles | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/QuickQuickSettings.kt` |
| Expanded grid | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/TileGrid.kt` |
| Tile surface and state colors | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt` |
| Shared tile content and dimensions | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/CommonTile.kt` |
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

### Preserved Android tokens

| Concern | Preserved source |
|---|---|
| Active color | `MaterialTheme.colorScheme.primary` / `onPrimary` |
| Inactive surfaces | `LocalAndroidColorScheme.surfaceEffect1` and `surfaceEffect2` |
| Unavailable state | Existing surface/on-surface-variant alpha treatment |
| Typography | Platform `titleSmallEmphasized` and `labelMedium` |
| Tile height | 72 dp compact; existing qualified values elsewhere |
| Toggle target | 56 dp compact; existing qualified values elsewhere |
| State and accessibility | `QSTile.State` to `TileUiState` conversion |
| Tooltip shape | Dedicated token preserving the upstream radius |

No literal colors are introduced. Wallpaper-derived dynamic color, light/dark pairing, contrast behavior, and unavailable-state semantics remain Android-owned.

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

All images contain representative states in one test-owned frame: active Bluetooth/mobile data, inactive Wi-Fi, and unavailable Cast. Their comparison shows the rounded-rectangle hierarchy and reduced glyph weight without changing the platform-owned state palette.

## Validation contract

1. Build focused `SystemUI` and `SystemUITests` targets.
2. Run the existing tile behavior and state/accessibility test classes.
3. Rebuild product images incrementally.
4. Run two clean Cuttlefish boots from the modified image.
5. Require distinct home/Quick Settings images, a SystemUI hierarchy, clean target crash/ANR classification, complete evidence, graceful stop, and no lingering transport.
6. Compare the modified screenshot with the stock baseline and confirm all representative states remain distinguishable.

## First-slice validation

- AOSP commit: `7a6ec03afcd84148e966a65eba74330967d012f2`
- Locked parent: `94b4c163b7dfe5ce3607f7bb8456f9573f7de57d`
- Exported patch: `patches/0003-frameworks-base-quick-settings-shape-tokens.patch`
- Patch SHA-256: `923c7e0afbb8d68bc52868c7479fc07de666d28a40aef9571e5153633533f200`
- Focused targets: `SystemUI` and `SystemUITests` passed.
- On-device focused evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T070528Z`
- Focused result: 41 passed, 0 failed across token, tile interaction, state, policy, and accessibility-role tests.
- Incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T065403Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T071022Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T071420Z`

Both accepted runs passed the SystemUI hierarchy and screenshot gates, target crash/ANR scan, bugreport collection, same-build graceful stop, and post-stop transport/process checks. Their source manifests and complete product-image checksum sets are identical.

## Second-batch validation

- AOSP commit: `a25ecd17bfee2711fc3194d396d4de6f225632df`
- Parent: `7a6ec03afcd84148e966a65eba74330967d012f2`
- Exported patch: `patches/0004-frameworks-base-quick-settings-layout-tokens.patch`
- Patch SHA-256: `04eb5b21a2e0140e9c62c7acc11e5a138255e909bf9bf3c6e1380e81f6c6e41e`
- Focused evidence: `/home/azureuser/android-test-artifacts/systemui-qs-tests-20260812T080219Z`
- Focused result: 57 discovered, 48 passed, 9 upstream configuration assumptions, 0 failed. This includes token aliases and values, tile interaction, edit-mode operations, state/accessibility mapping, and overlay tests.
- Incremental product build: `/home/azureuser/android-test-artifacts/aosp-build-20260812T080649Z`
- Accepted identical-input Cuttlefish pair:
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T081409Z`
  - `/home/azureuser/android-test-artifacts/cuttlefish-20260812T081829Z`

The first launch after product packaging normalized the generated `super.img` and `userdata.img`; component partition images were unchanged. The accepted pair was captured after that one-time normalization and has identical source manifests and complete product-image checksum sets. Both runs passed all runtime, evidence, crash/ANR, and clean-stop gates.

## Batched follow-up work

Further typography, brightness, toolbar/footer, detailed-view, motion, and configuration work will be grouped into materially larger coherent batches. Each batch uses one focused build/test cycle after editing, followed by one incremental product build and final runtime validation. This avoids rebuilding product images after individual token changes while retaining the milestone evidence gates.
