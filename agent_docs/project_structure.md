# Project Structure

## Directory Layout

- `AGENTS.md` — mandatory agent instructions and safety boundaries.
- `README.md`, `context.md`, `plan.md`, `ROADMAP.md` — project purpose, facts, execution plan, and milestones.
- `docs/design/` — Fluent implementation standard, material mapping, and Quick Settings contracts.
- `docs/adr/` — architecture and repository/publication decisions.
- `docs/` — host bring-up, testing, dashboard, and notification procedures.
- `manifests/` — Repo manifests, exact locks, and manifest documentation.
- `patches/` — historical patch documentation and retained patch references.
- `scripts/` — build, sync, smoke, preflight, dashboard, and Telegram operations.
- `config/` — host security and service configuration.
- `tests/` — shell safety, dashboard security, and repository-level validation.

## Modules and Responsibilities

The control repository owns policy, contracts, reproducibility boundaries, evidence requirements, and operational tooling. AOSP implementation lives in external checkouts and is consumed through manifest-pinned independent repositories. The dashboard is private and tailnet-only; Telegram is an advisory private notification channel.

## Main Interfaces and Integration Boundaries

The manifest and exported lock are the compatible-set boundary between control documentation and AOSP projects. Scripts communicate with AOSP through Repo/build tooling and with Cuttlefish through the owned ADB instance. Documentation links define the human and agent-facing contract. No source project is vendored into this repository.

## Tests and Supporting Assets

`make validate` checks repository documentation and script safety. `tests/` contains repository-level validation. Runtime evidence is retained outside Git under `/home/azureuser/android-test-artifacts`; AOSP build output is retained under `/home/azureuser/aosp-out` and exposed at `/mnt/aosp/out-fluent`.
