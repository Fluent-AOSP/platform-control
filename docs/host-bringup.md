# Host inventory and bring-up log

Observed 2026-08-11. This is evidence for the current reference host, not a portable installer specification.

## Machine

| Item | Observed |
|---|---|
| Cloud / size | Azure `Standard_D16ads_v5`, South India |
| OS | Ubuntu 26.04 LTS (`resolute`), x86_64 |
| Kernel | `7.0.0-1011-azure` |
| CPU | 16 vCPU, AMD EPYC 7763; AMD-V exposed through Microsoft hypervisor |
| Memory | approximately 62 GiB usable; no swap |
| KVM | `/dev/kvm` present and successfully opened by `azureuser`; `kvm-ok` passed |
| Virtualization modules | `kvm_amd`, `kvm`, `vhost_vsock`, `vhost_net` loaded |
| Root filesystem | ext4, approximately 493 GiB available at observation |
| `/mnt` filesystem | 600 GB virtual disk/ext4, approximately 590 GiB available after setting reserved blocks to 0%; filesystem already occupied the partition |
| Limits | 524,288 open files; high process limit |

The AOSP requirement is commonly expressed as 64 GB RAM and 400 GB free storage. Linux reports the host's nominal 64 GB as roughly 62 GiB; build concurrency must remain conservative and OOM behavior must be monitored.

## Paths

- Control repository: `/home/azureuser/fluent-aosp`
- AOSP source: `/mnt/aosp`
- Build output: `/home/azureuser/aosp-out`
- Test evidence: `/home/azureuser/android-test-artifacts`
- Android SDK: `/opt/android-sdk`
- SDK AVD home: `/mnt/android-avd`

All operational scripts allow environment overrides.

## Installed toolchain

| Component | Version/selection |
|---|---|
| Repo launcher | launcher 2.54; Ubuntu package `2.58-4` |
| Git | 2.53.0 at bring-up |
| Python | host Python 3.14.4; AOSP uses source prebuilts where supplied |
| C/C++ build essentials | GCC 15.2.0, Make 4.4.1, Ninja 1.13.2, CMake 4.2.3 |
| ccache | 4.12.3 |
| Cuttlefish host packages | `cuttlefish-base` and `cuttlefish-user` 1.55.1 |
| QEMU | Ubuntu QEMU 10.2.1 package line |
| Android command-line tools | 22.0 |
| Android Emulator | 37.1.11 |
| Platform Tools | 37.0.1 |
| SDK system image | `system-images;android-36;default;x86_64`, revision 2 |
| Bootstrap AVD | `aosp-bootstrap-api36` |

Cuttlefish groups `kvm`, `cvdnetwork`, and `render` include `azureuser`. New login sessions are required after group changes.

## Bring-up actions and evidence

1. Inspected CPU, memory, block devices, filesystems, KVM, limits, and tool availability.
2. Confirmed the 600 GB `/mnt` partition/filesystem was already at maximum provisioned size.
3. Reclaimed roughly 30 GiB previously reserved for root on the data-only ext4 filesystem by setting reserved blocks to 0%; no partition rewrite was needed.
4. Installed AOSP build prerequisites, Repo, ccache, Cuttlefish host support, QEMU/KVM utilities, Android command-line tools, Emulator, platform-tools, and the default API 36 x86_64 image.
5. Verified `/dev/kvm` is readable/writable and openable as the build user; Emulator acceleration check reported KVM usable.
6. Booted the dedicated SDK AVD headlessly with KVM and SwiftShader, waited for `sys.boot_completed=1`, captured screenshots/logs/UI data, and stopped the owned process.
7. Initialized `/mnt/aosp` on `android17-release` at manifest commit `29ace668ae756c7b8917c57abb440f6518844b0c`. The first source sync was interrupted by anonymous `android.googlesource.com` HTTP 429 throttling and two partial project initializations.
8. Quarantined and rebuilt only the malformed `system/ca-certificates` and `external/vulkan-headers` metadata, rebuilt the absent `frameworks/base` Git index from its pinned HEAD, completed low-concurrency network/local sync passes, and verified `repo status` clean. `manifests/aosp-android17.lock.xml` pins all 1,084 projects; superproject use is disabled and omitted from the lock.
9. Re-ran preflight in a fresh login context after group changes: all 22 original checks passed, including KVM open and Emulator acceleration.
10. The first full product compilation reached 84% before a Trusty action proved that Ubuntu's fallback `unprivileged_userns` AppArmor profile denied `nsjail` mount setup. Installed the narrowly scoped profile retained at `config/aosp-nsjail.apparmor`, loaded it with `apparmor_parser`, and verified the exact Soong sandbox probe succeeds. The global `kernel.apparmor_restrict_unprivileged_userns=1` policy remains enabled. Preflight now includes this probe when the source-provided binary exists.
11. Enabling the sandbox exposed further Android 17 command generation that prepends `$PWD` to an absolute external output path. Kept physical output at `/home/azureuser/aosp-out`, but standardized AOSP's path spelling as relative `OUT_DIR=out-fluent` through a validated `/mnt/aosp/out-fluent` symlink. Build and Cuttlefish scripts create the alias only when absent and reject mismatched/existing non-symlink paths.

Legacy bootstrap evidence: `/home/azureuser/android-test-artifacts/bootstrap-20260811T152831Z`

- `home.png`: valid 1080×2400 PNG.
- `quick-settings.png`: valid 1080×2400 PNG.
- Startup target crash/ANR scan: clean.
- Fingerprint: `Android/sdk_phone64_x86_64/emu64x:16/BE2A.250530.026.D1/13818094:userdebug/test-keys`.

This bootstrap predates the current full smoke contract: it proves basic KVM, ADB, screenshots, and startup scanning, but lacks several evidence/stop artifacts now required for an accepted run.

Current-contract SDK evidence: `/home/azureuser/android-test-artifacts/sdk-emulator-20260811T184359Z`

- Dedicated AVD/port ownership and AVD-name verification passed.
- Required screenshots, UI hierarchy, dumpsys/exit info, all-buffer logcat, and bugreport were nonempty.
- Java/native crash and ANR scan was clean.
- Graceful console stop succeeded, the owned PID exited, and no emulator transport remained; `PASS` was written only afterward.

## Known host risks

- The exact Ubuntu 26.04 + Android 17 + Cuttlefish combination is not explicitly certified in the official documentation. A locally built Cuttlefish smoke boot remains the decisive test.
- There is no swap, and reported memory sits close to AOSP's recommendation. Default build concurrency is intentionally below `nproc`; monitor peak RSS and OOM logs.
- Root and `/mnt` are different filesystems. Source and output free-space checks must be evaluated separately.
- `/mnt` may have different Azure disk IOPS/latency than root; elapsed build time remains unmeasured.
- Anonymous AOSP fetches from this Azure egress address have produced HTTP 429 responses. Sync defaults to four jobs; retries should be bounded and back off rather than creating a tight retry loop.
- Package repositories and named branches move. Accepted builds must record exact package versions and a revision-locked manifest.
- The SDK license files were accepted during host bring-up, but repository automation must not infer authorization from that fact or accept agreements silently on another host.
- Ubuntu 24.04 and later restrict unprivileged user namespaces through AppArmor. AOSP and Trusty use the checked-in `nsjail` binary for build sandboxes. Install only the scoped profile rather than disabling the global restriction:

  ```bash
  sudo install -o root -g root -m 0644 config/aosp-nsjail.apparmor /etc/apparmor.d/aosp-nsjail
  sudo apparmor_parser -r /etc/apparmor.d/aosp-nsjail
  ```

  The profile path assumes the approved `/mnt/aosp` source location and must be reviewed if `AOSP_ROOT` changes.

## Read-only recheck

```bash
make preflight
```

The preflight checks current reality; this log is only a historical observation.
