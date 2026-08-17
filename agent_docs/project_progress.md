# Project Progress

## Deployment Status


## Goal

Maintain a reproducible, evidence-based AOSP Android 17 adaptation governed by the Windows 11 Fluent visual language and Android platform contracts.

## Overall Progress

The repository baseline, host tooling, exact manifests, independent project repositories, normative design standard, and published Quick Settings milestones are established. Expanded Quick Settings and the published collapsed phone baseline remain pinned at `30634ab7b94629146d13f2b5ac97cb5b5dd71c6f`; final acceptance hardening remains in progress.

## Current Position

The unified collapsed shade source is published at framework commit `30fb4c2a3e2b8ae3ff9d69598c979fae5f4e6a04` and authoritative manifest commit `4d07fb6b`. Phone portrait renders the first four controls as 2×2, alerting and silent entries form one visual list, and inactive QS tiles/notification cards share exact runtime-selected shell-card roles. Production compilation, hot-deploy, dark/light/no-blur runtime evidence, matching APK identity, clean crash/ANR scan, and independent review are complete. Focused tests remain blocked by the unrelated `SystemUI_test_fixtures` compile error; final acceptance is not claimed. A new label-inside collapsed-tile experiment is pending and is not part of the published commits.

## Next Milestone

Unblock and run focused tests, then validate landscape, RTL, 200% font scale, TalkBack/input, no-blur and false-config fallbacks, keyguard/privacy/DND/global-clear behavior, product images, and a clean same-input Cuttlefish pair before any publication decision.
