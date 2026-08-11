# UI customization architecture

## Objectives

Create a recognizable Fluent visual voice with the smallest maintainable delta from AOSP. No device/HAL work is in scope. Android behavior, accessibility, safety, and information architecture are invariants.

## Layering

1. **Upstream Android roles and behavior**
   - Keep Monet/dynamic palette generation, Android semantic color pairs, component state machines, accessibility semantics, navigation, gestures, haptics, and window/inset logic.
2. **Fluent semantic alias layer**
   - Define aliases for neutral/brand/status foregrounds and containers, typography hierarchy, spacing, shape, stroke, elevation level, icon optical size, and motion.
   - Map aliases to Android roles rather than raw global values.
   - Keep View resources and Compose tokens semantically aligned where Android 17 uses both.
3. **Surface adapters**
   - Consume aliases in SystemUI first, then shared Settings/app themes.
   - Adapt native controls; do not replace Android controls with WinUI implementations.
4. **Optional effects**
   - Blur/translucency lives behind a capability/config gate with opaque fallback, reduced-transparency behavior, privacy review, and performance budget.
5. **Evidence and rollback**
   - Every token/surface change has before/after screenshots, semantic checks, accessibility coverage, and a narrow revert path.

## Source-change preference

Prefer in order:

1. existing resource/config overlays where runtime behavior and contrast remain correct;
2. a small product/theme layer for defaults and shared aliases;
3. narrow resources/Compose-theme changes in the owning project;
4. behavior code only when necessary to expose a visual token—not to imitate Windows behavior.

Do not assume Runtime Resource Overlays can safely express every dynamic/privileged SystemUI role. Inventory Android 17 resources and overlayability before implementation.

## Quick Settings first

Owning tree: `frameworks/base/packages/SystemUI/`.

Initial seam contract:

- **Behavior owned by AOSP:** shade expansion physics, tile lifecycle and state, Internet/connectivity composition, ordering/editing, long-click intents, lockscreen/privacy policy, notification/media relationships, accessibility actions, haptics, cutouts/insets.
- **Visual layer owned by the Fluent adaptation:** semantic surface/foreground selection, spacing, shape/stroke, icon optical treatment, typographic hierarchy, and local state-transition timing within Android motion settings.
- **Composition:** aliases resolve through Android theme/dynamic roles; component adapters consume aliases without bypassing state semantics.
- **Validation handoff:** built-image Cuttlefish loop plus screenshot/semantic/accessibility/performance matrix.

Pilot states: inactive, active, unavailable/disabled, and one transient detail panel. Solid/tonal backgrounds are the baseline. No per-tile Acrylic.

## Settings

Owning tree: `packages/apps/Settings/` plus shared platform resources.

Use native preference/search/deep-link infrastructure. Preserve whole-row activation, summaries, main switches, radios, admin-disabled states, and adaptive list/detail behavior. Visual configuration is integrated where users already expect it:

- display-related visual choices in Display;
- accessibility fallbacks in Accessibility;
- sound/haptic choices in Sound & vibration;
- wallpaper/dynamic-color policy in the existing wallpaper/style location where the AOSP product supports it.

There is **no** “Fluent,” fork-name, “custom ROM,” or “OS-specific settings” category. A setting that has no coherent existing owner requires product review, not a dumping-ground menu.

## Dialer and apps

Owning tree: `packages/apps/Dialer/` for the AOSP phone Dialer selected by the manifest.

Theme through the app's existing base theme hierarchy. Preserve emergency, DTMF, proximity, permissions, answer/decline/end, and call-state semantics. Critical telephony glyph/color changes require a safety review. Cuttlefish can validate navigation and visuals but not real carrier/IMS behavior.

## Token governance

Each token has:

- semantic name and intent;
- Android role/source;
- light/dark/dynamic/contrast behavior;
- fallback;
- consuming surfaces;
- accessibility requirement;
- screenshot/test coverage.

Avoid component-named raw values such as `qsBlue` or `settingsCardGray`. Prefer intent names such as `fluentColorContainerSelected` mapped to the correct Android container role. Never pair a container from one dynamic role with an unrelated `on*` foreground.

## Icons and assets

Fluent System Icons may be introduced only after license inventory and metaphor review. Store source, license, attribution, conversion command, viewport, optical size, RTL behavior, and content-description impact. Do not assume fonts, product icons, illustrations, or sounds share the System Icons license.

## Feature/config strategy

- Use existing settings/configuration mechanisms when appropriate.
- Experimental visual effects default off and degrade to opaque/reduced-motion behavior.
- Do not add a parallel settings database or privileged service for visual tokens.
- Avoid a global “enable Fluent” switch unless product authority later approves a real multi-theme requirement; the project itself is the design adaptation, not an app theme pack.

## Review gates

- **Blocker:** lockscreen/shade privacy or contrast regression.
- **Blocker:** emergency/call-state semantic regression.
- **High:** hard-coded color bypasses dynamic/contrast pairing.
- **High:** native control/accessibility semantics replaced.
- **High:** blur/translucency lacks opaque fallback or jank/power evidence.
- **Medium:** change could be an overlay/token but directly forks behavior code.
- **Medium:** a setting is placed outside its established owning category.

## Rebase discipline

Keep customization commits grouped by token foundation and narrowly scoped surface adapters. Do not mix manifest updates, host tooling, behavior refactors, and visual changes. On every upstream lock update, rebuild the unmodified baseline first, then replay and validate each layer.
