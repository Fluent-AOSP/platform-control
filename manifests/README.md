# Locked manifests

`Fluent-AOSP/android` is the authoritative Repo manifest for the fork. Its `fluent-android17` branch pins unchanged projects to Android Gitiles and modified projects to independent `Fluent-AOSP` source repositories.

This directory keeps two reviewed records:

- `aosp-android17.lock.xml` — the original unmodified upstream baseline used during bring-up.
- `fluent-android17.lock.xml` — the current complete source lock, including exact Fluent project commits.

`scripts/aosp-init-sync.sh` initializes from `https://github.com/Fluent-AOSP/android.git`, syncs the pinned tree, and exports `fluent-android17.lock.xml` with `repo manifest -r`. The exporter strips trailing whitespace and removes the disabled `<superproject>` entry. Every retained project revision is a 40-character object ID.

Review every manifest and project revision change. Do not hand-edit commit IDs, update the lock incidentally with a UI change, or treat a moving branch alone as reproducible input. Modified-project publishing and update policy is defined in [ADR 0002](../docs/adr/0002-project-repositories.md); upstream selection remains defined in [ADR 0001](../docs/adr/0001-aosp-baseline.md).
