# Project Overview

## Purpose

Fluent AOSP is the control and documentation repository for adapting AOSP Android 17 toward a coherent Windows 11 Fluent visual language while preserving Android behavior, accessibility, security, privacy, state production, and adaptive-layout contracts.

## Scope

The repository governs the AOSP source checkout, revision-locked Repo manifests, independent Fluent-AOSP project repositories, design contracts, architecture decisions, build/runtime evidence, validation scripts, and private notification operations. It does not contain the AOSP checkout itself.

## Architecture

- `AGENTS.md` is the mandatory entry point for coding agents.
- `context.md` records durable product and environment boundaries.
- `docs/design/` contains normative implementation and surface specifications.
- `docs/adr/` records architecture and publication decisions.
- `manifests/` defines exact upstream and Fluent revisions.
- `scripts/` provides explicit, parameterized host, build, smoke-test, and notification operations.
- `/mnt/aosp` is the external AOSP checkout; `/home/azureuser/aosp-out` is the retained physical output location.

## Main Workflows

Validate documentation and scripts with `make validate`; use the pinned manifest for sync; build with the configured AOSP output alias; run focused tests and same-input Cuttlefish/SDK evidence loops; review evidence before publication; then pin published project revisions in the manifest and exported lock.

## Major Decisions

- Windows 11 and official Microsoft Fluent/WinUI guidance are the visual authority.
- Android owns behavior and platform contracts; Fluent work is UI-design work unless an approved platform-owned integration exception applies.
- Quick Settings uses transient Acrylic with compositor-owned blur and explicit opaque/no-blur/privacy/performance fallbacks.
- Modified AOSP projects are independent, non-fork repositories with complete upstream history.
- New project-authored commits use `Foxtrot47 <jjneutron@outlook.com>` and Conventional Commit subjects.
