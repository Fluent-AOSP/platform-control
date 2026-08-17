# Project Diary

## Durable Decisions

- The central control repository is `/home/azureuser/fluent-aosp`; the AOSP checkout at `/mnt/aosp` is an external implementation workspace.
- Durable agent documentation belongs under the central workspace's `agent_docs/`, not under the external AOSP project.
- The collapsed 4×2 Quick Settings experiment was rejected because its composition looked poor and its separator/chevron alignment was not acceptable.
- The collapsed baseline returns to a 2×2 arrangement and retains AOSP expansion behavior plus real dual-target separator/chevron affordances.
- The medium-route prototype uses 2×2 only for phone portrait; landscape and `sw600dp` retain the platform adaptive collapsed layout.
- Notification card drawables must start from the opaque semantic role because the non-transparency `SRC_ATOP` tint path preserves destination alpha.
- Alerting and silent notifications remain distinct Android buckets but form one Fluent visual list; only an immediately adjacent alerting/silent boundary loses its header, gap, and section-only edge roundness.
- Notification cards use pinned generic WinUI card semantics; `#EFFFFFFF` light and `#B72C2C2C` dark are derived Android source-over compositions of `ControlOnImageFillColorDefault` under `CardBackgroundFillColorDefault`, not claimed Windows notification-shell constants.
- Inactive QS tiles and notification cards share `fluent_shell_card_*`; the shared role is tile-specific and must not replace broad Material `surfaceContainer`/`outlineVariant` roles used by toolbar, footer, edit, rails, or unavailable states.
- Published unified shade source: `30fb4c2a3e2b8ae3ff9d69598c979fae5f4e6a04`; authoritative manifest pin: `4d07fb6b`.

## Lessons

A successful build and a single screenshot do not establish visual acceptance. Layout relationships, transitions, accessibility semantics, adaptive behavior, fallback behavior, and independent review must be evaluated together.
- Hot-deploy evidence is valid only when the final formatted source is rebuilt and the local/deployed APK hashes match.
- Visual section merging must not fold noncontiguous Android buckets into one `SectionBounds`; restore actual section roundness each pass, then suppress only the currently shared adjacent edge.
- A drawable selector can be mutated during `setCustomBackground`; normal translucent and opaque card tints must explicitly restore the Fluent state list while true app tints retain platform contrast-selected states.
- Cross-surface equality requires shared runtime dispatch, not only equal resource literals: compatibility, scene, overlay, and collapsed QS hosts must use effective blur/transparency state rather than a compile-time flag default.

## Evidence References

- `/home/azureuser/android-test-artifacts/fast-iteration-cvd/cycle-collapsed-two-by-two-notification-cards-29/`
- `/home/azureuser/android-test-artifacts/collapsed-qqs-two-by-two-notification-cards-build-20260814T142203Z/`
- `/home/azureuser/android-test-artifacts/fast-iteration-cvd/cycle-resumed-medium-20260817/`
- `/home/azureuser/android-test-artifacts/fast-iteration-cvd/cycle-combined-notifications-20260817/`
- `/home/azureuser/android-test-artifacts/fast-iteration-cvd/cycle-winui-card-tokens-20260817/`
- `/home/azureuser/android-test-artifacts/fast-iteration-cvd/cycle-unified-shell-surfaces-20260817/`
- `docs/design/fluent-implementation-standard.md`
- `docs/design/quick-settings-foundation.md`
