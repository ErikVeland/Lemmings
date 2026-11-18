# Ultimate Lemmix loaded-asset parity implementation plan

> For agentic workers: use `superpowers:executing-plans` for integration and focused parallel investigations for the independent import and presentation boundaries.

**Goal:** A complete owned Ultimate Lemmings 2.4.2 resource import restores the same game presentation, content, controls and local game behaviour after activation and relaunch.

**Architecture:** Keep the full application and unchanged NxlvKit engine. Resolve imported data through `GameResources`. Original selection must delegate to the existing renderers and media readers. Retain separate application branding, installation identity and Store distribution configuration.

**Tech stack:** Swift 6, AppKit, shared mobile modules, existing native integration harness and muted offscreen runner.

**Spec:** The owner's 17 November 2026 instruction and [Ultimate Lemmix](UltimateLemmix.md).

## Constraints

- Compare with baseline `b294d3b7c298f549aad5faa36f92ba9bf23b7529` and the installed 2.4.2 application.
- Keep NxlvKit fingerprint `9a246f97fd42930d53c273a4bb9c45800f0379fd7326f7c65518d484ebfeeea5` unchanged.
- Keep original assets outside the clean application and Git.
- Keep tests muted and offscreen, with isolated preferences and saves.
- Leave the running Mac build 107 unchanged.
- Run only focused parity checks. Do not start broad corpus or release audits.

## Review focus

- A complete pack must retain every supported asset family and the current trusted metadata.
- Import and relaunch must select Original consistently without a stale Lix cache or preference.
- Original fonts, buttons, portraits, cursor shapes and sequel poses must use their native paths.
- Content IDs, menu actions, checkpoints, player rosters and queue ownership must survive resource changes.
- A single DOS folder must remain a partial data import and cannot claim complete restoration.

## Tasks

- [x] Inspect the complete source pack, import policy and existing fixtures. Reproduce any missing or changed assets before fixing the importer.
- [x] Compare Original rendering and media selection with the reference resources. Add a focused failing regression before each production fix.
- [x] Exercise complete import, activation and cold restoration in isolated storage. Compare resource hashes, content identities, menu/control contracts and representative native renders across game families.
- [x] Build the corrected current-architecture Mac candidate if code changes. Compile affected mobile targets, record exact coverage and update the parity register.

## Acceptance evidence

Record actual commands and results under `.build/ultimate-lemmix-asset-parity`. Retain the concise result and limits with this plan. Compilation alone does not satisfy loaded-asset parity. Hosted services and physical input require separate device and service evidence.

The [build 108 record](ReleaseReadiness/ultimate-lemmix-2.4.2-build108/README.md)
records the completed import, rendering, identity, recovery and widget-boundary checks.
