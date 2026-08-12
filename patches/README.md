# Source compatibility patches

The revision lock remains an unmodified upstream AOSP baseline. Apply the patches
in numeric order after syncing and before building. Each patch is narrow,
reviewable, and recorded separately from the generated manifest lock.

## Soong/Siso external `OUT_DIR`

`0001-build-soong-siso-external-out-dir.patch` applies to project
`build/soong` at locked revision
`6722dd8833db7482df1a2543ca3fcf67ddf0f7b1`.

Android 17's Soong integration generates Siso configuration beneath `OUT_DIR`
and passes that directory as `--config_repo_dir`. Bundled Siso v1.5.8 requires
the flag to be relative to its execution root. With the approved external
`OUT_DIR=/home/azureuser/aosp-out`, the unpatched build fails before compilation
with `failed to load @config//main.star` even though the file exists.

The patch converts the generated path to an execution-root-relative path and
adds unit coverage for both relative and absolute external output directories.
It does not relocate output or change product behavior.

## CI test packaging with an external `OUT_DIR`

`0002-build-soong-ci-tests-external-out-dir.patch` fixes the next bootstrap
failure in the same `build/soong` project. The CI test packager previously used
a string-prefix heuristic to distinguish product files from host files. That
heuristic only worked when `OUT_DIR` began with the literal relative path
`out`; an absolute host JAR was consequently passed to `PathForModuleOut` and
rejected as outside the module directory.

The patch uses `filepath.Rel` plus an explicit containment check, preserving the
intended exclusion of host files for both relative and absolute output roots.
It adds focused tests for product files, host files, and sibling directories.

## Quick Settings semantic shape tokens

`0003-frameworks-base-quick-settings-shape-tokens.patch` applies to project
`frameworks/base` at locked revision
`94b4c163b7dfe5ce3607f7bb8456f9573f7de57d`.

The patch introduces component-semantic Quick Settings shape dimensions for
active/inactive icon wells and tile surfaces, keeps the existing shared resource
names as aliases, and preserves the tooltip's original geometry with a dedicated
token. Compact tiles move from pill/circle treatment to rounded rectangles;
large/desktop qualified values receive the same hierarchy. Dynamic colors,
tile state mapping, typography, touch-target dimensions, clicks, long-clicks,
and accessibility behavior are unchanged. Focused tests enforce alias identity,
state distinction, and compact minimum touch targets. Applying the patch produces
local commit `7a6ec03afcd84148e966a65eba74330967d012f2`; the patch SHA-256 is
`923c7e0afbb8d68bc52868c7479fc07de666d28a40aef9571e5153633533f200`.

## Quick Settings semantic layout tokens

`0004-frameworks-base-quick-settings-layout-tokens.patch` applies after patch
0003, at local `frameworks/base` revision
`7a6ec03afcd84148e966a65eba74330967d012f2`.

The patch adds component-semantic icon-size and content-spacing resources,
reduces compact glyph sizes while retaining tile and toggle targets, and makes
normal and resize-mode edit tiles share the same compact 8 dp content rhythm.
Desktop effective glyph sizes and 6 dp content spacing are preserved explicitly;
inter-tile edit-grid spacing remains independent. It also resource-backs the
unchanged logical start/end padding and extends token and overlay tests. Applying
the patch produces local commit `a25ecd17bfee2711fc3194d396d4de6f225632df`;
the patch SHA-256 is
`04eb5b21a2e0140e9c62c7acc11e5a138255e909bf9bf3c6e1380e81f6c6e41e`.

## Quick Settings semantic chrome shapes

`0005-frameworks-base-quick-settings-chrome-shapes.patch` applies after patch
0004, at local `frameworks/base` revision
`a25ecd17bfee2711fc3194d396d4de6f225632df`.

The patch adds compact and `sw600dp` semantic shape tokens for the shade panel,
brightness container, edit-grid containers, toolbar protected background, and
non-interactive toolbar feedback. It makes the brightness focus outline follow
the same corner and frame expansion as its background. Slider behavior, dynamic
colors, edit operations, toolbar interaction/focus shapes, clicks, semantics,
and touch-target dimensions remain unchanged. Applying the patch produces local
commit `9f67040d68f04f1dec7c347134fc7a18a2a232a7`; the patch SHA-256 is
`af32d1bb42f434556740a0edced54f3bf460f74136954ff9a447c62c44ca7658`.

## Windows 11 Fluent Quick Settings composition

`0006-frameworks-base-windows11-fluent-quick-settings.patch` applies after patch
0005, at local `frameworks/base` revision
`9f67040d68f04f1dec7c347134fc7a18a2a232a7`.

The patch aligns the shared Quick Settings renderer and both footer/toolbar host
paths with Windows 11 as the canonical visual reference. It establishes 4 dp
persistent-control and 8 dp overlay geometry, 12 dp compact gutters, dense 56 dp
tiles over 48 dp targets, 20 dp icon optics, full-surface active emphasis, flat
inactive split targets with subtle dynamic strokes, a compact brightness
container, and Windows-like type proportions. Edit, tooltip, security, feedback,
settings, and power surfaces use the same hierarchy. Android owns state
production, dynamic role pairing, gestures, slider behavior, editing, lockscreen
policy, accessibility semantics, and adaptive layout. Applying the patch produces
local commit `e2210836149cee234211a39dc44e866bf0219650`; the patch SHA-256 is
`f14cb09530e6fc750b4a8085fca301686815d007532528dac0423bc813499d27`.

## Fluent Quick Settings color and material roles

`0007-frameworks-base-fluent-quick-settings-colors.patch` applies after patch
0006, at local `frameworks/base` revision
`e2210836149cee234211a39dc44e866bf0219650`.

The patch installs one Quick Settings-scoped Material color mapping across the
compatibility, scene, and overlay hosts. Active controls use audited Windows-blue
light/dark role pairs; inactive, unavailable, edit, toolbar, footer, tooltip, and
brightness surfaces use cool neutral roles. Translucent control fills reveal the
platform shade blur when available, while explicit opaque light/dark fills cover
the no-blur path. Shared brightness defaults remain unchanged outside Quick
Settings. Applying the patch produces local commit
`9f104c3c949e777bebe6f9f57da0d9667f7f055a`; the patch SHA-256 is
`e28b75330ed051ad3145c08ee1f4e126fd48082815ada1b807289f595719e8f2`.

Apply to a clean locked checkout:

```bash
cd /mnt/aosp/build/soong
test "$(git rev-parse HEAD)" = 6722dd8833db7482df1a2543ca3fcf67ddf0f7b1
git am /home/azureuser/fluent-aosp/patches/0001-build-soong-siso-external-out-dir.patch
git am /home/azureuser/fluent-aosp/patches/0002-build-soong-ci-tests-external-out-dir.patch
../../prebuilts/go/linux-x86/bin/go test ./ui/build ./ci_tests

cd /mnt/aosp/frameworks/base
test "$(git rev-parse HEAD)" = 94b4c163b7dfe5ce3607f7bb8456f9573f7de57d
git am /home/azureuser/fluent-aosp/patches/0003-frameworks-base-quick-settings-shape-tokens.patch
test "$(git rev-parse HEAD)" = 7a6ec03afcd84148e966a65eba74330967d012f2
git am /home/azureuser/fluent-aosp/patches/0004-frameworks-base-quick-settings-layout-tokens.patch
test "$(git rev-parse HEAD)" = a25ecd17bfee2711fc3194d396d4de6f225632df
git am /home/azureuser/fluent-aosp/patches/0005-frameworks-base-quick-settings-chrome-shapes.patch
test "$(git rev-parse HEAD)" = 9f67040d68f04f1dec7c347134fc7a18a2a232a7
git am /home/azureuser/fluent-aosp/patches/0006-frameworks-base-windows11-fluent-quick-settings.patch
test "$(git rev-parse HEAD)" = e2210836149cee234211a39dc44e866bf0219650
git am /home/azureuser/fluent-aosp/patches/0007-frameworks-base-fluent-quick-settings-colors.patch
```

The resulting local commits are expected to be recorded by the build evidence's
revision manifest. Do not amend the upstream lock to the local-only commits.

## Output path strategy

The physical output remains `/home/azureuser/aosp-out`. Build and Cuttlefish
scripts create and validate `/mnt/aosp/out-fluent` as a symlink to that storage,
then pass the relative `OUT_DIR=out-fluent` to AOSP. Android 17 still contains
additional sandbox command generation that prepends `$PWD` to output paths;
using the source-root alias avoids corrupting those paths while retaining the
larger root filesystem for output. Scripts refuse to replace an existing path
or a symlink that resolves anywhere else.
