# Source compatibility patches

The revision lock remains an unmodified upstream AOSP baseline. Apply the patches
in this directory after syncing and before building. Each patch is narrow,
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

Apply to a clean locked checkout:

```bash
cd /mnt/aosp/build/soong
test "$(git rev-parse HEAD)" = 6722dd8833db7482df1a2543ca3fcf67ddf0f7b1
git am /home/azureuser/fluent-aosp/patches/0001-build-soong-siso-external-out-dir.patch
../../prebuilts/go/linux-x86/bin/go test ./ui/build
```

The resulting local commit is expected to be recorded by the build evidence's
revision manifest. Do not amend the upstream lock to the local-only commit.
