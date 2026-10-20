# 2.1 build 93 release record

Published on 20 October 2026 at [GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.1).
Release source: `4f4075880f03c1feb157fb4e1fe488dd938af31a`. Release base: `v2.0.7`.
The [release notes](../../ReleaseNotes-2.1-build93.md) describe the Mac release.
iOS and tvOS retain their separate versions and acceptance records.

## Packages and updates

Both universal Mac apps contain Apple silicon and Intel code and target macOS
12.3 or later. Both passed Developer ID signature verification, Apple
notarisation, stapling and Gatekeeper after archive extraction. The full update
retains the verified published soundtrack. The slim installer contains the 54
main versions and offers optional libraries separately. Public credits exclude
the private supporter ledger.

The five signed direct deltas, from builds 91, 90, 87, 86 and 85, each produced
18,567 matching files and links, including file permissions, and passed signature
verification. The installed public Ed25519 key verifies the full update and all
five deltas. All seven uploaded assets passed GitHub size/digest and public HTTPS
checks. The signed feed matches remote main and its public HTTPS response.
[Publication receipts](publication.json) retain URLs, sizes, SHA-256 hashes and
Apple submission IDs. [Delta checks](delta-verification.json) retain each base.

## Source and regression evidence

The app compiled from `90b3c4f2d835b6247db8f982e4497553ac2e4325`. The final source commit changes only two
test fixtures. All source, resource, script, tool, package and bundled-note Git
objects are identical between those commits. [Source provenance](source-provenance.json)
records that comparison. No signed app input changed when the final notes and
feed received the release revision.

The broad native audit initially passed 46 checks. Its ten initial failures
remain recorded locally. Fresh replacements pass after updating old presentation
and session assertions and granting the required macOS service access. The broad
app checks pass as the original prefix and corrected Journey/session remainder.
The original audit also records generated resource, test and documentation drift.
Every engine Swift file matches its frozen audit copy. The final source/resource
snapshot and each replacement are recorded in the
[verification summary](verification-summary.json).

The native rescue audit checks 562 level identities and 615 configurations. It
reproduces all 294 retained population certificates and 315 rescue records. Six
primary configurations remain unknown. The hint exporter replays the accepted
Classic routes before writing the current engine stamp and rejects bonus-skill
replays as sources for standard hints. Existing campaign and fidelity limits
remain in [release scope](../../ReleaseScope.md).

Additional checks pass: 92 release-tool tests, ten localisation/picker tests,
64 focused Swift tests, two replay checks with the bundled engine fingerprint,
three inspection UI tests, five engine fixture groups,
five mobile Extra skill regressions against optimised candidate libraries, and
About packaging. The debug mobile L2 test exceeded its worker stack. The same
five cases pass against the optimised shipping libraries.

Native feature checks cover free Zoom, independent presentation, Extra skills
and receipts in all three games, Short games, About, result navigation and the
25× control. Records, movie export, solo/shared checkpoints and Hot Seat ghosts
pass. The sequel artwork audit checks 59,542 frames and 214 levels. Its exact
round-trip captures now park the test pointer so live hover fading cannot affect
the comparison. Settings bounds compare rendered pixels after fractional menu
scaling. The [compact welcome](welcome-900.png) and
[settings capture](settings-1000.png) were inspected, with their input targets.

All native UI checks used `Tools/UITestRunner/run.py`, offscreen and muted.
Metal, media, native registration and signature checks required macOS service
access outside the sandbox. The sandbox also reports an invalid signature for
the original accepted app, while the same checks pass with service access.
No check changed system volume or saved player audio settings.

The bundled Ports, fan and NeoLemmix files match 2.0.7 byte for byte. See the
[content comparison](content-equivalence.json). Each translated locale retains
current translations and uses explicit English fallback for 160 new strings.
The catalogue has 3,275 keys and no uncovered direct interface literals.

## Remaining acceptance

Signed foreground first launch, direct updater installation/relaunch, physical
mouse/touch/controller/remote input, real VoiceOver, live cloud propagation,
human language and newcomer review, audible tone, sustained device loads and
composited HDR appearance remain unverified. The signed-app launch test cannot
run under the offscreen-only instruction. Completed asynchronous Short games
preview artwork also remains visually unchecked.

Mac Short games supports Classic and L2. L3 reserve snapshots and mobile sequel
playlist playback remain unavailable. Existing L3 route and source-fidelity gaps
stay open. Individual inspection does not establish cross-level survivor identity.
Publication does not certify a separate iOS or tvOS build or close those gates.
