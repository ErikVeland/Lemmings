# Macintosh 2.0 build 83

Status: [2.0 build 83 is public](https://github.com/ErikVeland/Lemmings/releases/tag/v2.0). Both universal packages have
Developer ID signatures, accepted Apple notarisation tickets and stapled tickets.
Quarantined archive extractions pass Gatekeeper. The signed full update, signed
build-82 delta and live automatic-update feed are verified.

Release source: `1b4daa28adee3f3b05399e61775c1be201caf349`. The owner requested Macintosh 2.0 and
approved the existing classifications on 15 October 2026: “Use existing
classifications and document limits.” The [acceptance record](acceptance.json)
defers six milestone areas for this release only. No open engine, content,
hardware or accessibility gate is marked closed. Classic and The Tribes retain
Complete. Chronicles and NeoLemmix remain Beta.

## Candidate evidence

The [consolidated evidence](fresh-audit.json) records 55 passing checks.
At the owner's request, passed checks are retained where engine, gameplay,
shared libraries and non-localisation resources are unchanged. The
[equivalence record](production-source-equivalence.json) lists all source
changes and verifies the unchanged payload. Both executable architectures were
[freshly rebuilt](rebuild-localised.log) after inclusion of the language packs.
The only Mac code change after the original candidate is release-note wording.

The [raw audit](raw-audit.json) retains its two native compilation failures and
one changed test file. The fixtures referenced the removed keyboard-help API.
The [native rerun](native-repaired.log) corrected obsolete Back placement,
explicitly attached the result fixture, and selected the actual retry button
rather than its duplicate text label. Owner and paused-restart assertions remain
intact. Its final ghost-render assertion failed. Explicit render diagnostics showed the fixture still in the Home campaign flow, with title LEMMINGS and ghost tick zero. It now enters the real playing flow, cancels pending Home work through the normal render path and uses an explicit bitmap context. Only that check and the
previously uncompiled sequence check were run in the
[remaining native rerun](remaining-repaired.log), which passes the ghost and
all six Solo/Hot Seat checkpoint paths. Earlier failed logs remain available.
The [raw audit report](raw-audit.md) links the original results.

The retained [macOS CI run](https://github.com/ErikVeland/Lemmings/actions/runs/38676897405) passes shared tests, the universal Release
build and tooling for `eb6d58d7d86597ab0114f364d6707aa050bdb80e`. It was not rerun for the language-resource
change, following the owner's instruction. [CI reuse](ci-reuse.json) records the
exact source relationship and the fresh local universal build.

[Language validation](localisation-validation.json) passes 3,118 text entries
and eight plural tables for each added language. The
[shipping-bundle check](localisation-shipping.log) resolves all 24,944 strings
across English and seven added languages, plus 320 plural cases. Full and slim
apps contain identical language bundles and declare all eight locales. Human
language review and complete translated-screen/device validation remain open.

The [witness refresh](witness-refresh.json) verifies all 352 Classic and
conversion identities and retains 171 winning Tribes configurations. Every
published target under unchanged rules is retained. Chronicles uses the new
`l3-native-preview-v2` comparison identity for its corrected Mole behaviour.
Eighty-six standalone witnesses replay twice. Shadow 7 and Egyptian 6, 13 and
29 remain gaps. Earlier-rules records remain historical and do not certify
current rescue goals. The active catalogue has 294 proofs and 315 rescue records.
Classic hint verification covers 352 identities with 350 unique fingerprints.

Muted offscreen checks cover the 1-bit artwork selector, live artwork changes,
all backpack patterns, gameplay targeting, cursor movement and shared navigation.
The panel checks capture selected, paused and unavailable timeline states at
900, 1280 and 1600 points, and verify input targets. Captures remain under
`.build/release-2.0-current/source/.build/mac-monochrome-captures` with the
commercial artwork. The initial panel fixture omitted the original panel skin
and assumed empty skills were disabled. Its corrected fixture passes, and
[the raw failure](monochrome-panel.log) and [rerun](monochrome-panel-rerun.log)
remain available. Release-note captures also verify scrolling and Continue.

The [candidate record](candidate-inputs.json) verifies both architectures,
macOS 12.3 metadata, all 1,307 unchanged game-data proof inputs and current
bundled hints and certificates. The [soundtrack record](soundtrack-preservation.json)
retains all 649 Music files and 32 MacMusic files byte for byte from the verified
public soundtrack. All recording source hashes and playback parameters match.
The full app contains 495 soundtrack versions. The slim app contains 54 essential
versions and offers optional libraries.

## Distribution

[Publication receipts](publication.json) record archive sizes, SHA-256 hashes,
matching GitHub asset digests, Apple submission IDs and live download responses.
The [delta verification](delta-verification.json) checks its Ed25519 signature
and every reconstructed payload file against the final full app. The full
archive signature also verifies against the public key in the shipping app.
Existing update-feed enclosures and descriptions are preserved. Both public
archives, the final app, notes and receipts are copied to Downloads and checked
again. See [Downloads verification](downloads-final.json).

## Retained limits

The stricter bundled-content closure remains open. Fan content retains 3,621
route gaps. Seventy-five bundled NeoLemmix levels reference missing styles,
and exact-version winning evidence covers 158 levels. L2's golden-talisman ark
ending, L3 carried-route repair, source-engine fidelity and exposed media/story
transitions remain unfinished. This release does not claim full campaign or
bundle closure beyond the accepted existing classifications.

Physical controller and VoiceOver journeys, audible listening, foreground
shipping-app launch, minimum-OS and Intel hardware, HDR appearance and live
cross-device synchronisation remain manual gaps. All automated native tests
use the required offscreen runner with muted audio. No test changes system
volume, takes focus or switches displays. This release publishes Macintosh
only. iPhone, iPad and Apple TV have separate release gates.
