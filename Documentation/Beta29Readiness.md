# Beta 29 readiness

Version 0.1, build 29. Universal arm64 and x86_64, macOS 13 or later.
Full soundtrack assets are included. This is the standard local-records build.

## Release status

The universal app is Developer ID signed with hardened runtime and a timestamp.
Apple accepted submission `b980b008-f898-497e-9987-2caefb2166e4`. The ticket is stapled and validated.
The finished ZIP was extracted, marked as downloaded, and accepted by Gatekeeper
as Notarized Developer ID. Strict signature checks passed.

Tester download: `/Users/veland/Downloads/UltimateLemmings-beta29-macOS.zip`.
SHA-256: `4c973cb68b9ff2b4dad2e9d5021f6043d19d5bf41c400d0326089763637949ca`.
The archive is 406.7 MiB and includes `Release Notes.md`.
Matching notes are in Downloads. Beta 28 remains available as a fallback.

## Scope

This release removes 23 empty or malformed fan levels and preserves saved queue
identities. All 6,020 retained fan levels load and start. It adds seven official
Classic winning routes, three conversion routes and five full-rescue certificates.
The Bottom Falls audio option applies across Classic, Lemmings 2 and Lemmings 3.
See [release notes](ReleaseNotes-beta29.md).

## Frozen inputs and validation

Inputs are copied into `.build/beta29/source`. The input manifest records the
base commit and the working-tree snapshot. No frozen input changed during the
build. The 3,568 source, test, script, tool, resource and content inputs match
the validated Classic candidate, except for build number 28 becoming 29.

The earlier candidate audit passed 49 checks. Its strict completion gates remain
open because winning routes are missing. Its initial app check rejected an
invalid new test fixture. After that fixture was corrected, both full app
journeys passed on native Apple silicon and in the Intel binary under Rosetta.
These include pruned queue recovery, controls, hints and paused Hot Seat ownership.
The sequel artwork and UI checks passed. The original audit and corrected app
results are retained separately; the failed audit is not presented as green.

For this cut, all 18 Swift tests passed. Bottom-fall audio admission passed for
Macintosh, Amiga fallback, L2 and L3. The signed production app passed startup
checks on both architectures. Physical Intel hardware was not tested.

All 9,523 packaged resource files were compared with the tested candidate.
Twelve regenerated lossless soundtrack containers differ in bytes, but their
decoded audio exactly matches both the candidate and the frozen source WAVs.
Every other resource is byte-identical. Every archived app file matches the
signed app, and the archived notes match the frozen release notes.

Logs, hashes, the source comparison, audio comparison and package verification
are under `.build/beta29`. `release-results.json` records the final handoff.

## Remaining limits

Classic 1.0 remains open. Verified routes cover 230 of 292 official levels,
389 fan levels and three of 60 conversions. The retained corpus has 622 wins
and 5,750 identities without winning evidence, with no load/start failures.
L2 and L3 remain previews. Hardware, physical controllers, full VoiceOver,
sustained 10× performance and the other recorded 1.0 gates remain open.
