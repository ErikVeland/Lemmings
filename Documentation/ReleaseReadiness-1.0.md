# 1.0 gap review

11 September 2026. Scope: the current macOS game. This review does not declare a 1.0 release.

This document records the changes and the gate table. For the ranked open work and the 1.0 scope decision, see the [1.0 gap evaluation](ReleaseReadiness/OneZeroGapEvaluation.md).

## Changes

- Added **Settings → Accessibility → Reduce added motion**. It disables speed trails and cinematic explosions across classic, L2 and L3 play.
- Added **Reduce added flashes**. It disables added bright explosion cores, HDR flashes and cinematic explosions across those engines. Original game sprites remain.
- Both settings preserve gameplay speed and controller support. They survive relaunch and both experience and machine preset changes.
- Added settings migration, persistence, policy, live app and sequel-view regression checks. The first sequel run caught a flash-toggle interaction with speed effects. The fix clears only explosion effects.
- Corrected Adaptive DJ fade timing. Fades follow elapsed time when rendering delays callbacks, while suspended output preserves the remaining fade. Added delayed-main-thread and suspension regressions.
- Added L3 winning-replay validation to the standard release audit.
- Extended audit hashes to include source assets, bundled test assets, resources and campaign evidence. Changed or removed inputs invalidate the run.
- Made strict closure fail for skipped checks and open gates. Added negative tests for these cases and asset changes.
- Made fan-level index JSON ordering deterministic for repeatable package inputs.
- Corrected stale README claims about campaign completion, converted levels and the current development version.

The effect reductions are specific presentation controls. They do not establish complete accessibility support or a flash-free game.

## Save hardening follow-up

The [save recovery work](SaveRecovery.md) adds validated arcade backups, preservation of unreadable files, stale-writer protection, non-blocking file locks and profile-save rollback with an in-game retry. It also fixes the shipping app's legacy migration gate and carries forward manual L2 slots, fan progress and saved preferences. Classic and NeoLemmix sessions now reject negative skill indices instead of indexing an array with them.

Five follow-up check groups passed, including the full app integration and profile-retry UI tests. See [the evidence](../.build/release-audit/save-hardening/results.json) and [the newer universal development app](../.build/release-audit/save-hardening/Ultimate%20Lemmings.app).

That earlier follow-up predates the in-progress checkpoints added in the [current blocker work](ReleaseReadiness/BlockerFollowup.md). The full recovery gate remains open.

## Remaining gates

| Area | Work needed for closure |
| --- | --- |
| Original campaign | Keep all 120 winning routes passing. Original-engine equivalence remains a separate claim. |
| Oh No!, Xmas and Holiday | Preserve winning routes for 69 remaining levels: Oh No! 34, Xmas 1992 one, Holiday 1993 eighteen, Holiday 1994 sixteen. |
| Lemmings 2 | Record the remaining 56 routes, verify continuous carry-over progression and resolve fidelity differences against original-engine evidence. |
| Lemmings 3 | Record the remaining 74 routes, resolve provisional mechanics, and complete environmental effects, movie soundtracks and story transitions. |
| Converted and imported levels | Complete converted-level winning evidence and representative supported NeoLemmix pack playthroughs. Render/release checks alone do not prove a solution. |
| Recovery and upgrades | Classic, fan, NeoLemmix, sequel campaign and L2 practice checkpoints are implemented. Verify power-loss recovery, migrations and rollback against installed prior releases. |
| Accessibility and input | Remapping, device prompts, text/menu scaling and broader VoiceOver navigation are implemented. Verify full journeys with VoiceOver, physical controllers and novice players. |
| Hardware and performance | Test physical Intel, macOS 13, SDR/HDR, multiple displays, high refresh rates, sustained 10× play, memory growth and audio stability. |
| Online services | Validate provisioned Game Center, network failure and offline behaviour. |
| Distribution | Freeze the actual candidate, build both architectures, sign, notarise and verify its downloaded archive. Resolve the recorded publishing and asset-distribution gate. |

The 199 missing core campaign routes exclude converted levels. Route counts come from the committed campaign manifests, read on 12 September 2026. Missing evidence does not prove a level is broken. Do not replace these gates with passing smoke tests or a version-number change.

iPhone, iPad and consoles remain separate delivery projects. The current repository has no working app target for those platforms. They are not implied by a future Mac 1.0 release.

See the [full gate register](ReleaseReadiness/gates.json) for exit criteria and the [modern release plan](ModernReleasePlan.md) for platform work.

## Validation

The [initial audit](../.build/release-audit/1.0-gap-audit/report.md) ran 40 checks: 39 passed and the sequel-view check failed. It recorded no input drift. The engine/data, original completion, additional campaign, L3 replay, input, HDR and certificate checks passed.

The first follow-up exposed the DJ timing bug. Its failed log remains at `.build/release-audit/1.0-app-followup/app.log`.

After both fixes, the complete [Mac integration suite](../.build/release-audit/1.0-final-app/app.log) and [sequel suite](../.build/release-audit/1.0-final-app/sequel.log) passed. Their [results and input manifest](../.build/release-audit/1.0-final-app/results.json) record no drift during these final runs. The engine and replay inputs stayed unchanged after their passing checks. The deterministic fan-index packaging change followed these app checks and has a separate build verification.

These are local development results. They do not establish hardware coverage, complete campaigns or distribution approval.


## Earlier local build

The fresh [Universal app](../.build/release-audit/1.0-build/Ultimate%20Lemmings.app) is under `.build/release-audit/1.0-build`. The existing `.build/local` app was preserved. This is a development build with the existing version metadata, not a 1.0 release or a newly notarised archive.

- Optimised arm64 and x86_64 builds succeeded. Both executable slices target macOS 13.
- The local ad-hoc signature passed strict, deep verification.
- Bundled-resource and unified-game tests passed against this new package.
- Repeated fan-index generation and the packaged index have identical SHA-256 hashes.
- The build input manifest recorded no drift. The copied build script changes only the output location and preserves the production build steps.

[Build log](../.build/release-audit/1.0-build/build.log), [package checks](../.build/release-audit/1.0-build/integrity.json), [architecture evidence](../.build/release-audit/1.0-build/architectures.log), [input manifest](../.build/release-audit/1.0-build/inputs.json), and [bundle hashes](../.build/release-audit/1.0-build/bundle-manifest.json) remain with the package.

## Rewind follow-up

The next recovery pass fixes lost keyframe commands, stale future branches, replay input timing and invalid rewind durations. It also repairs the shared engine fingerprint used by rescue verification. See [save and rewind recovery](SaveRecovery.md). Disk checkpoints and the other release gates remain open.

## Hint presentation and candidate build follow-up

- All level hint text and numbered map markers now use the menu bitmap font.
- Shared bitmap paragraph wrapping preserves line breaks, skill arrows and long words.
- Long hint text scrolls with mouse, keyboard and controller input. Each tier starts at the top.
- Bitmap hint text exposes its complete value to accessibility tools.
- The local build script accepts `LEMMINGS_BUILD_DIR` for an isolated candidate build without copying or modifying the script.

Validation for this pass is recorded in [the presentation review](ReleaseReadiness/HintPresentation.md).
These changes close the hint typography and overflow defects. The campaign, fidelity,
hardware, service and distribution gates above remain open.

## Checkpoint, controller and packaging follow-up

[The blocker follow-up](ReleaseReadiness/BlockerFollowup.md) records Classic campaign disk recovery, persistent controller remapping, device prompts and corrected Developer ID packaging. It also records the passing regression checks and the measured high-speed shortfall with replay recording enabled. These changes do not close the remaining campaign, sequel, accessibility, hardware or external approval gates.


## Post-beta-20 local closure

The [local closure record](ReleaseReadiness/OneZeroLocalClosure.md) covers Classic
fan and L2 practice checkpoints, a fresh-start Hot Seat action, accessibility
callback isolation, and the earlier checkpoint-file and hint fixes. These changes
follow beta 20. Its frozen archives do not include them.
