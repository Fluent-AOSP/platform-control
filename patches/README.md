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

Apply to a clean locked checkout:

```bash
cd /mnt/aosp/build/soong
test "$(git rev-parse HEAD)" = 6722dd8833db7482df1a2543ca3fcf67ddf0f7b1
git am /home/azureuser/fluent-aosp/patches/0001-build-soong-siso-external-out-dir.patch
git am /home/azureuser/fluent-aosp/patches/0002-build-soong-ci-tests-external-out-dir.patch
../../prebuilts/go/linux-x86/bin/go test ./ui/build ./ci_tests
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
