# Locked manifests

After the first reviewed sync, `scripts/aosp-init-sync.sh` exports `aosp-android17.lock.xml` here with `repo manifest -r`.

The lock file is generated evidence but intentionally tracked. The exporter strips trailing whitespace and removes the manifest `<superproject>` entry because sync explicitly uses `--no-use-superproject`; every retained project revision is a 40-character object ID. Review every revision change. Do not hand-edit project SHAs, update it incidentally with a UI change, or treat a named branch alone as reproducible input. See [ADR 0001](../docs/adr/0001-aosp-baseline.md).
