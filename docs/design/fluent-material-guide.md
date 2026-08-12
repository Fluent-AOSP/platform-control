# Fluent 2 and Material/Android design guide

## Purpose

This guide defines the translation rules for a cohesive Fluent system on Android. Windows 11 shell surfaces are the canonical visual reference: the result should look recognizably similar in geometry, density, hierarchy, strokes, materials, typography proportions, and motion. Android behavior, accessibility, security, and adaptive-layout contracts remain hard constraints; WinUI code and desktop-only interaction models are not transplanted.

“Material” here means current Material 3/Material You guidance. AOSP SystemUI is not necessarily implemented with the same library stack as an app using Material 3, so inspect the pinned Android 17 source before choosing an implementation seam.

## Core principles

| Fluent 2 term | Meaning | Android translation |
|---|---|---|
| Natural on every platform | Adapt to device and native conventions; use familiar patterns for most experiences | Preserve Android navigation, controls, gestures, insets, haptics, adaptive behavior, semantics, and system settings |
| Built for focus | Reduce clutter and emphasize the current task | Calm neutral hierarchy, purposeful spacing, fewer decorative dividers; do not cardify every row |
| One for all, all for one | Inclusion is foundational | The stricter of Android accessibility and Fluent/WCAG guidance wins |
| Unmistakably Microsoft | Create a coherent, recognizable Fluent identity | Use Windows 11 geometry, density, control strokes, surface layering, icon optics, typography hierarchy, and motion consistently—not as isolated decorative details |

Sources: [Fluent design principles](https://fluent2.microsoft.design/design-principles), [Fluent accessibility](https://fluent2.microsoft.design/accessibility), [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility).

## Tokens: the integration seam

Fluent distinguishes raw/global tokens from semantic alias tokens. Material 3 also uses semantic roles. Build a small translation layer rather than scattering literal values across SystemUI and apps.

| Fluent concept | Material/Android role | Rule |
|---|---|---|
| Neutral background/foreground/stroke | `surface*`, `onSurface*`, `outline*` | Preserve complete foreground/container pairs under dynamic color and contrast changes |
| Brand background/foreground/stroke | `primary`/`onPrimary` and container pairs | Reserve for selected/high-emphasis states; do not flood persistent surfaces with Microsoft blue |
| Shared/status colors | error plus audited warning/success pairs | Status must not rely on hue alone; safety-critical Android conventions win |
| Spacing aliases | `dp` resource/Compose dimensions | Use a 4 dp rhythm while retaining 48 dp hit targets |
| Typography aliases | Android text appearances/Compose roles in `sp` | Match the Windows 11 12/16 and 14/20 regular/semibold hierarchy using scalable, redistributable fonts and complete locale fallback |
| Radius/stroke/elevation | Android shape and surface tokens | Use Windows 11's 4 dp control and 8 dp overlay hierarchy as the starting point; adapt only where Android ergonomics require it |
| Duration/easing | Android motion resources/specs | Preserve gesture continuity, predictive back, animator scale, and reduced-motion behavior |

Sources: [Fluent design tokens](https://fluent2.microsoft.design/design-tokens), [Material color roles](https://m3.material.io/styles/color/roles), [AOSP Material You](https://source.android.com/docs/core/display/material).

## Terminology and translation

### Color

**Fluent:** neutral, brand, and shared/status palettes, with aliases for rest, hover, pressed, selected, disabled, light, and dark contexts.

**Material/Android:** HCT-derived primary, secondary, tertiary, neutral, and neutral-variant tonal palettes mapped to semantic roles; Android can derive them from wallpaper.

**Rule:** keep Monet/dynamic color and accessible role pairing. A Fluent brand seed may be harmonized for selected/high-emphasis roles or offered as an explicit theme policy, but must not silently replace wallpaper personalization. Android has no persistent hover state on touch; focus/hover support still matters for mouse, keyboard, and accessibility input.

Sources: [Fluent color](https://fluent2.microsoft.design/color), [Fluent color tokens](https://fluent2.microsoft.design/color-tokens), [Material color system](https://m3.material.io/styles/color/system/overview), [AOSP dynamic color](https://source.android.com/docs/core/display/dynamic-color).

### Typography

**Fluent:** caption/body/subtitle/title/large-title/display semantics, baseline alignment, deliberate weight and line height. Segoe is a Windows/web signature, but Fluent guidance uses native fonts and specifies Roboto for Android.

**Material/Android:** display/headline/title/body/label roles, scalable `sp`, font-scale and locale fallback contracts.

**Rule:** match Segoe UI Variable's hierarchy and openness with licensed, redistributable Android fonts; never redistribute Segoe without rights. Preserve locale fallback and scalable `sp`. Test 200% font scale, long translations, bold text, baselines, truncation, and screen-reader order.

Sources: [Fluent typography](https://fluent2.microsoft.design/typography), [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility).

### Layout and spacing

**Fluent:** a 4 px global rhythm with occasional optical corrections; grouping and hierarchy come from spacing, grids, gutters, margins, alignment, and baselines. Fluent explicitly identifies 48×48 as the Android mobile target minimum.

**Android:** density-independent dimensions, window size classes, edge-to-edge insets, cutouts, fold posture, and at least 48 dp interactive targets.

**Rule:** Windows effective pixels map naturally to Android `dp` for the visual baseline. Keep the 4 dp rhythm, 12 dp compact gutters, and small visible controls while preserving at least 48 dp hit targets. Use Android breakpoints and preserve compact, split-screen, landscape, foldable, desktop/freeform, and external-input behavior.

Sources: [Fluent layout](https://fluent2.microsoft.design/layout), [Android adaptive layouts](https://developer.android.com/design/ui/mobile/guides/layout-and-content/adapt-layout).

### Shape

**Fluent:** form, corner radius, and stroke; rectangle, circle, pill, and beak are named forms. Web examples often use small radii, while mobile guidance defers to iOS/Android conventions.

**Material/Android:** a larger shape scale and familiar pills, circles, sheets, dialogs, switches, sliders, and tiles.

**Rule:** use the Windows 11 geometry hierarchy directly where the component role matches: 4 dp for persistent controls and bars, 8 dp for flyouts, dialogs, and overlay containers, and 0 dp where adjoining straight edges meet. Keep circles only for genuinely circular metaphors or controls. Android touch bounds may exceed the visible geometry.

Sources: [Windows 11 geometry](https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/geometry), [Fluent shapes](https://fluent2.microsoft.design/shapes).

### Depth and elevation

**Fluent:** perceived z-distance, often a sharp key shadow plus softer ambient shadow, with named shadow ramps.

**Material/Android:** elevation plus tone-based surface-container separation; platform rendering determines shadows and overlays.

**Rule:** map base/control/transient/modal levels. Prefer tone and restrained strokes for persistent mobile surfaces; reserve shadows for real overlap. Do not copy Fluent/Windows numeric shadow values.

Sources: [Fluent elevation](https://fluent2.microsoft.design/elevation), [Material styles](https://m3.material.io/styles).

### Motion

**Fluent:** purposeful, physically credible, consistent, occasionally delightful; enter/exit, elevation, top-level fades, and container transforms; provide a no-motion path.

**Material/Android:** motion explains navigation/state and participates in gestures, predictive back, haptics, and system animator settings.

**Rule:** focus Fluent pacing on local microinteractions. Never replace shade drag physics or predictive-back choreography. State must remain understandable with animation disabled.

Source: [Fluent motion](https://fluent2.microsoft.design/motion).

### Iconography

**Fluent:** system icons are literal, recognizable metaphors; product-launch and file icons are distinct categories. Fluent System Icons are MIT-licensed, but that does not license every Fluent asset.

**Android:** Material Symbols and platform-familiar navigation, connectivity, status, accessibility, and telephony glyphs.

**Rule:** substitute only when the metaphor remains familiar. Normalize optical size/stroke, provide content descriptions, mirror directional icons in RTL, and retain Android-standard critical glyphs (back, overflow, signal, battery, emergency, answer/decline/end call).

Source: [Fluent iconography](https://fluent2.microsoft.design/iconography).

### Controls

Microsoft's Fluent Android library is an evolving subset designed to coexist with native Material components, not a complete SystemUI toolkit.

**Rule:** theme/wrap native Android controls; do not import WinUI state machines. Switch, radio, slider, sheet, dialog, ripple/pressed, TalkBack action, keyboard/D-pad, and haptic behavior remain Android contracts.

Source: [Fluent Android components](https://fluent2.microsoft.design/components/android).

## Windows 11 materials on Android

Fluent names solid, Acrylic, Mica, and smoke materials. Their visible hierarchy is part of the target; Android implements equivalent intent with its own blur, tint, scrim, dynamic-color, privacy, and performance mechanisms.

| Material/effect | Portable intent | Android policy |
|---|---|---|
| Solid | Reliable opaque surface and hierarchy | Opaque fallback and accessibility baseline using dynamic tonal surfaces |
| Smoke | Modal separation/dimming | Map to Android's standard modal scrim and dismissal behavior |
| Acrylic | Transient frosted context | Use Android background blur plus tint for transient light-dismiss surfaces when supported; require opaque, reduced-transparency, privacy, battery, and frame fallbacks |
| Mica | Wallpaper-tinted persistent backdrop | Approximate the visual relationship with Android dynamic color and subtle tonal layering; do not claim Windows compositor behavior |

Desktop title bars, NavigationView/command bars, hover-only state design, WinUI control state machines, and Windows compositor APIs remain nonportable. Their appearance can guide equivalent Android surfaces without importing their behavior.

Sources: [Fluent material](https://fluent2.microsoft.design/material), [Windows materials](https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/materials), [Windows Acrylic](https://learn.microsoft.com/en-us/windows/apps/design/style/acrylic), [Windows Mica](https://learn.microsoft.com/en-us/windows/apps/design/style/mica).

## Surface rules

### Quick Settings — first

Preserve collapsed/expanded states, tile ordering/editing, Internet/connectivity behavior, status semantics, long-press destinations, shade gestures, haptics, notifications/media relationships, cutouts/insets, lockscreen privacy, and accessibility actions.

Start with semantic tokens for neutral surfaces, full-control active emphasis, subtle inactive strokes, unavailable state, 4 dp control/8 dp overlay geometry, 12 dp compact gutters, dense 56 dp visible tiles over 48 dp minimum targets, and consistent Fluent icon optics. Use transient blur/tint when the platform supports it and retain an opaque fallback. Validate state without color, dynamic wallpaper/contrast combinations, TalkBack, RTL, landscape/large screens, and frame performance.

AOSP landmarks: `frameworks/base/packages/SystemUI/` and dynamic-color consumers around `ThemeOverlayController`; exact Android 17 seams must be inventoried before editing. See [AOSP connectivity UI](https://source.android.com/docs/core/connect/connectivity-ui).

### Settings

Preserve category ownership, search/indexing, deep links, summaries, main switches, radio patterns, admin-disabled states, and adaptive layouts. Use native preference components and restrained hierarchy. Do not place every row in a card.

Every new option belongs in its relevant existing category. There is no “Fluent settings,” fork-name, “advanced OS,” or other catch-all menu.

Sources: [AOSP Settings](https://source.android.com/docs/core/settings), [Settings guidelines](https://source.android.com/docs/core/settings/settings-guidelines).

### Dialer

Preserve emergency behavior, DTMF, call-state/proximity behavior, permissions, and the established meanings/colors of answer, decline, and end-call controls. Keep circular dial keys and system typography. Restrict initial icon substitution to noncritical secondary actions. Cuttlefish screenshots do not prove carrier/IMS correctness.

Source: [AOSP Dialer](https://android.googlesource.com/platform/packages/apps/Dialer/+/android17-release/).

## Accessibility and release gates

- Normal text contrast: at least 4.5:1; large text and non-text interactive visuals: at least 3:1.
- Touch targets: at least 48 dp.
- Test TalkBack, Switch Access, keyboard/D-pad, RTL, 200% font scale, bold/high-contrast text, color correction, reduced motion, light/dark/dynamic themes, and state without color.
- Treat lockscreen/shade blur privacy or contrast failures as blockers.
- Treat telephony safety-semantic regressions as blockers.
- Measure frame time and power before accepting blur, stacked translucency, broad shadows, or expanded motion.

## Signature traits to evaluate

A candidate should be recognizably Fluent through a small coherent set: calm neutral hierarchy, purposeful 4 dp spacing rhythm, restrained brand/dynamic accent, selected Fluent icon treatment, consistent strokes/shapes, and concise purposeful motion. If recognition requires breaking Android familiarity, the adaptation has gone too far.
