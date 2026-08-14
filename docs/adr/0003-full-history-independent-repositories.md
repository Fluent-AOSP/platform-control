# ADR 0003: Preserve full upstream history in independent project repositories

- Status: Accepted
- Date: 2026-08-14
- Supersedes: ADR 0002's snapshot-root history model

## Context

ADR 0002 moved modified AOSP projects from a patch queue into independent `Fluent-AOSP` repositories. Its initial bounded-history model used an exact upstream tree snapshot as a synthetic root. That retained source provenance but omitted native upstream commit history and blame from the project repository.

The project now requires complete upstream history for every modified AOSP repository. Some AOSP histories contain blobs larger than GitHub's normal client-push limit. GitHub's repository importer can transfer the archived `aosp-mirror` object database server-side into a new independent repository without establishing a GitHub fork relationship. The mirror is useful as a transport seed, but it is archived and is not authoritative for current Android revisions.

## Decision

Every modified AOSP project repository MUST:

1. be owned by `Fluent-AOSP`;
2. be an independent GitHub repository with `isFork=false`;
3. retain the complete upstream ancestry closure reachable from the exact selected Android Gitiles commit, including all parents, trees, and referenced objects, rather than a synthetic snapshot root; unrelated branches that are not reachable from the selected commit are not required by this rule;
4. use Android Gitiles as the authority for the selected Android branch and exact upstream commit;
5. extend an imported historical object set from Android Gitiles when the imported mirror is older than the selected baseline;
6. place individual Fluent commits after the exact selected upstream commit;
7. preserve project-authored commit boundaries;
8. use the approved project author and committer identity;
9. be pinned by exact commit ID in `Fluent-AOSP/android`.

The GitHub import source MAY be `aosp-mirror` when necessary to transfer historical objects that GitHub will not accept through a normal client push. This does not make `aosp-mirror` the source of truth. After import, the repository MUST be verified against Android Gitiles and advanced to the exact reviewed upstream commit before Fluent changes are published.

GitHub's **Import a repository** workflow is distinct from **Fork**. Contributors MUST NOT use GitHub's fork operation for project repositories.

## Authorship

Unless project authority explicitly changes it, every Fluent-authored commit uses both:

- Author: `Foxtrot47 <jjneutron@outlook.com>`
- Committer: `Foxtrot47 <jjneutron@outlook.com>`

VM-derived identities, `Ubuntu`, `Fluent AOSP Automation`, `Fluent AOSP Build`, service identities, and unrequested co-author trailers are prohibited for project-authored commits.

Upstream commits retain their original authors and committers.

## Verification

Before a repository is pinned:

- GitHub reports `isFork=false`.
- A non-shallow fetch directly from Android Gitiles resolves the selected commit and provides the authoritative ancestry closure.
- The byte-identical selected Gitiles commit object is an ancestor of the Fluent branch; because Git commit IDs cover their parent and tree references, retaining that exact connected object proves the same upstream ancestry rather than a reconstructed look-alike.
- The repository uses no graft or replace refs, and `git fsck --connectivity-only` passes on the fetched project repository.
- `git rev-list --count` and `git rev-list --max-parents=0` for the selected commit match the direct Gitiles fetch; counts and root IDs are recorded.
- The selected commit tree ID matches the direct Gitiles fetch.
- Fluent commits preserve intended tree sequence and messages.
- All Fluent-range authors and committers match the approved identity.
- The remote head is verified after push.
- The authoritative manifest and exported control lock pin the accepted head.

## Consequences

- Repository clones are larger, but native upstream history, commit identity, blame, and merge ancestry remain available.
- GitHub importer may be required for histories containing oversized historical blobs.
- Imports must not be confused with forks.
- The archived mirror cannot select or validate the Android 17 baseline; Android Gitiles remains authoritative.
- Rewriting a published Fluent range to repair provenance or authorship requires an explicit force-push decision and immediate manifest repinning.
- Snapshot-era commit IDs may remain in historical evidence, but current manifests use the full-history equivalents.
