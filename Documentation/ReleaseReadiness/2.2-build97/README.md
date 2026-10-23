# 2.2 build 97 release record

Mac published on 23 October 2026 at
[GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.2).
The frozen release source is `a9c154af8380a9371d73e66bbd6830ddfc5f6081`.
The [release notes](../../ReleaseNotes-2.2-build97.md) cover Desk Clock and
widgets, Duo entry and input recovery, reading pages, settings, calendar
cancellation and four exact bundled fan-level exclusions.

## Delivery

| Platform | Build | State |
| --- | ---: | --- |
| macOS | 97 | Published; full/slim universal downloads and the signed update feed verified. |
| iPhone/iPad/Duo | 20 | Waiting for Review in iOS Private Beta. Notes saved; automatic notifications enabled. |
| iPhone/iPad AltStore Classic | 20 | Published source and unchanged iOS export on the canonical 2.2 release. Device re-signing and installation not run. |
| Apple TV | 10 | Waiting for Review in TV Private Beta. Notes saved; automatic notifications enabled. |

All three archives use the frozen source. Mac application and widget contain
Apple silicon and Intel slices and require macOS 12.3 or later. The full
archive keeps all 495 soundtrack versions; the slim download keeps the 54 main
versions. The mobile exports contain both complete menu font banks. iOS keeps
the main soundtrack and its correctly identified widget; TV keeps the full
soundtrack and Top Shelf extension.

The Mac executable was compiled before the final metadata-only commit. Its
Swift inputs match the frozen source byte for byte; the English runtime
translation values also match. Final resources were staged after that commit.
Both mobile archives were refreshed at the frozen commit. The
[source manifest](source-provenance.json), [localisation comparison](localisation-equivalence.json)
and [Mac identity receipt](mac-bundle-identity.json) retain those checks.

Both Mac ZIPs passed CRC, size, signature, notarisation, stapling and Gatekeeper
checks after extraction. Five direct updates from builds 96, 95, 93, 91 and 90
reproduce all 18,943 files and links, including file permissions. Each patched
bundle passes code-signature validation. The installed Ed25519 public key
verifies the full update and all five patches. All seven public Mac assets match
their sizes and SHA-256 digests and respond over HTTPS. The live signed feed
matches remote main. See the [publication](publication.json),
[delta](delta-verification.json) and [signature](signature-verification.json) receipts.

The [mobile receipt](testflight.json) records both Beta Review submissions,
existing groups, saved note locales, automatic notifications, symbols and
validated export hashes. Upload separately exported each verified signed
archive; the validated export hash is not asserted as the uploaded IPA hash.
Browser status was retained as text. Automatic approval review rejected a
whole-window screenshot because it included unrelated private Safari tabs.

The [AltStore Classic source](../../../altstore.json) offers the same validated
iOS export, SHA-256 `516ecbf97362a2ac5e282ae08646bfca3b29591589b383caa622f006385c9cf9`.
The [AltStore receipt](altstore.json) checks the source metadata against the
IPA, CRC, both bundle signatures, unencrypted arm64 executables and the union
of app/widget entitlements and privacy descriptions. It also records public
source, icon and IPA verification. The [driver](drivers/verify-altstore.py)
repeats the local package checks. AltStore re-signing, installation, widget
acceptance and access to cloud or Game Center services remain unverified.
See the [AltStore guide](../../AltStore.md) for the stable source URL and the
separate PAL requirements.

## Source and verification

The source gate passed 528 shared tests. The release-tool suite passed 95 tests.
Ten native localisation and picker tests and 55 Desk Clock tests passed with
offscreen windows and muted audio. All eight draft language packs pass their
structure checks. The final catalogue has 4,912 message uses, 3,527 keys and no
unclassified UI literals. Human translation review remains open.
The final [repository check](repository-check.json) passed.

The original minor-release audit ran 56 checks with no source drift. Restricted
network, Metal and media services prevented eight checks from completing in the
sandbox. All 56 check commands have passing results after the background reruns
and test corrections below. Controls-help focus and desktop focus after Retry
remain explicitly skipped. The [validation receipt](validation.json),
[initial report](initial-audit.json), [input hashes](inputs.json) and
[rerun report](audit-reruns.json) retain the original failures and final results.

The home-screen integration test assumed the superseded Journey fraction label
and shared whichever profile previous tests left active. Its corrected fixture
uses an isolated player and checks both Start Journey and a returning Journey
Map with one saved win. The cached-text comparison now uses 1x and 3x source
glyphs: the renderer deliberately bypasses the line cache at 2x and 4x to draw
the authored display and countdown faces. The Hot Seat recovery assertion now
uses the current Resume Journey label and still checks the full roster,
checkpoint, paused state and owner. The unopened-fan-pack Journey fixture uses
a new player instead of inheriting the legacy player's earlier checkpoint;
it asserts that no checkpoint exists before checking sequence-only Resume.
These corrections affect test code only. Release-archive inputs remain at the
frozen cut. Later mobile HUD/performance work in the shared workspace is outside
this release and its validation.

Proof migration compared 151 engine files byte for byte and checked all 609
retained witness hashes: 294 rescue certificates and 315 records. The two new
fingerprint exclusions affect bundled menu eligibility and download progress.
This metadata migration adds no winning route and makes no new fidelity claim.
See the [migration receipt](../../TrolleyVerification/presentation-fingerprint-migration.json).

## Acceptance limits

Classic and The Tribes remain Complete; Chronicles and NeoLemmix remain Beta.
Full-corpus winning routes, source fidelity and the gate register retain their
open limits. Four exact impossible fan records are excluded from bundled play;
their original archives and imported copies remain available. Playable fan
scope is 6,016, with 2,404 verified routes and 3,612 open routes.

Foreground launch and actual updater installation/relaunch were not run under
the owner's offscreen-only instruction. Physical input, VoiceOver, widget
gallery and calendar permission acceptance, live cloud propagation, minimum-OS
and Intel hardware, sustained performance and physical Duo acceptance remain
open. Mobile Journey playback remains Classic-only. Upload and Beta Review
submission do not establish tester availability or physical-device acceptance.
