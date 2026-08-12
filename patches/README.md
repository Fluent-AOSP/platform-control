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
