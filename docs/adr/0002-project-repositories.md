# ADR 0002: Publish modified AOSP projects as source repositories

- Status: Accepted
- Date: 2026-08-12

## Context

The initial bring-up kept the upstream revision lock unchanged and exported every local change as an ordered patch. That was useful while proving the host, build, and Cuttlefish loop, but it does not scale to SystemUI, Settings, Dialer, and other independently versioned AOSP projects. A long cross-project patch queue makes review, rebasing, collaboration, and manifest reproducibility unnecessarily difficult.

The public `aosp-mirror` GitHub organization is archived and is not an acceptable source dependency for this project. Android Gitiles remains the authoritative upstream.

## Decision

Each modified AOSP project is published as an independent public repository in the `Fluent-AOSP` organization. Repository names follow the AOSP path convention, for example:

- `platform/frameworks/base` → `Fluent-AOSP/platform_frameworks_base`
- `platform/build/soong` → `Fluent-AOSP/platform_build_soong`
- future `platform/packages/apps/Settings` → `Fluent-AOSP/platform_packages_apps_Settings`

Repositories are not forks of `aosp-mirror`. Their root commit is an exact tree snapshot of a recorded commit fetched from `android.googlesource.com`, with the source URL, upstream commit, branch, and tree ID in the commit message. Normal Fluent commits follow that baseline. This bounded history model avoids transferring many gigabytes of unrelated upstream history while retaining byte-identical source provenance.

`Fluent-AOSP/android` is the authoritative Repo manifest. It pins unchanged projects directly to Android Gitiles and modified projects to exact commits in the Fluent repositories. The `fluent-android17` branch is for review and update flow; builds consume commit IDs, not moving branch names.

`platform-control` remains the compact control plane for automation, architecture records, test policy, and accepted visual evidence. Ordered patch files are no longer an active source-delivery mechanism. Historical patch artifacts remain available in Git history but are removed from the current tree to prevent two competing sources of truth.

## Update workflow

1. Fetch the reviewed upstream commit directly from Android Gitiles.
2. Record or update the exact upstream snapshot provenance.
3. Rebase or replay Fluent commits in the affected project repository.
4. Build and validate the resulting project commits.
5. Pin accepted commit IDs in `Fluent-AOSP/android/default.xml`.
6. Export and review `manifests/fluent-android17.lock.xml` in `platform-control`.

## Consequences

- Contributors clone and review ordinary project repositories instead of applying a growing patch series.
- Cross-project changes use a manifest commit to bind the exact compatible set.
- Published Fluent commit IDs differ from the earlier local patch-era IDs because the new repositories use pinned snapshot roots. The source trees are identical; old evidence continues to record the historical IDs that produced it.
- Upstream blame before the snapshot boundary is available through the recorded Android Gitiles commit rather than embedded in every Fluent clone.
- Any future modified surface requires a project repository and a manifest pin before it is accepted.
