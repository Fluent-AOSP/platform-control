# Project Core Technologies

## Languages and Runtimes

The control repository uses POSIX shell, Python, JavaScript, and Markdown. The governed product is AOSP Android 17, primarily using Kotlin, Java, C/C++, AIDL, XML resources, Soong Blueprint, and Repo manifests.

## Frameworks and Libraries

The implementation target is Android SystemUI and related AOSP framework/application components. Fluent icon assets come from the pinned Microsoft Fluent System Icons subset under its MIT license. Typography may request a product-provided `segoe-ui` family but must fall back safely; proprietary font binaries are not tracked.

## Build, Test, and Development Tools

AOSP builds use Soong with `OUT_DIR=out-fluent`. Repo sync uses the exact manifest and control-lock pins. Focused tests use AOSP test tooling, with ktfmt and `git diff --check` required for relevant changes. Runtime validation uses Cuttlefish at the established local ADB serial, screenshots, UI hierarchy dumps, logs, and bounded crash/ANR classification.

## External Services and Infrastructure

The primary runtime target is locally built Cuttlefish. The dashboard is private and tailnet-only. Telegram Bot API notifications are advisory and use a mode-0600 credential outside Git. GitHub hosts independent project repositories and the manifest; Android Gitiles remains upstream authority.

## Important Technical Constraints

Preserve Android behavior, accessibility semantics, 48 dp minimum interaction targets, RTL and adaptive layouts, lockscreen/privacy protections, live tile state, and no-blur/reduced-transparency fallbacks. Use compositor-owned backdrop blur rather than UI-library blur modifiers. Do not commit proprietary Segoe binaries or unreviewed assets. Builds and runtime evidence are not final acceptance without focused tests, adaptive/accessibility coverage, product validation, and independent review.
