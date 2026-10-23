# 2.2.1 build 98 release record

Mac published on 23 October 2026 at
[GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.2.1).
The frozen source is `285dbabd432ecdf3fc3414e087a92058b7018f0b`. See the
[release notes](../../ReleaseNotes-2.2.1-build98.md).

## Delivery

| Platform | Build | State |
| --- | ---: | --- |
| macOS | 98 | Published; universal full/slim downloads, five signed direct updates and the live updater feed verified. |
| iPhone/iPad/Duo | 21 | Waiting for Review. Existing groups, saved notes and automatic notifications verified. |
| AltStore Classic | 21 | Published source and the same validated iOS export on the canonical release. |
| Apple TV | 11 | Waiting for Review |

The Mac app, widget and six shared libraries contain Apple silicon and Intel
slices. Both Mac downloads passed signature, notarisation, stapling, archive CRC
and Gatekeeper checks. The full download keeps 495 soundtrack versions; the
slim download keeps 54 main versions. Direct updates from builds 97, 96, 95, 93
and 91 reproduce the final app's files, links and permissions. The installed
Ed25519 public key verifies the full update and all five patches.
See the [package identity](mac-bundle-identity.json), [notarisation](notarisation.json),
[delta](delta-verification.json), [signature](signature-verification.json) and
[public delivery](publication.json) receipts.

The iOS archive includes its correctly identified Desk Clock extension. The TV
archive includes Top Shelf. Both exported packages pass content, font,
signature and symbol checks. All 27 iOS and 18 TV localisation tables match the
frozen source. The [mobile receipt](testflight.json) records delivery status;
Apple processing and Beta Review determine external tester availability.
The [AltStore receipt](altstore-verification.json) checks the unencrypted IPA,
both bundle signatures and the declared permissions. Device re-signing and
installation remain unverified.

## Source and checks

Release work moved to an isolated checkout when another chat began editing
cloud-sync presentation. Those later changes are outside this frozen release.
The Mac artwork and executable were refreshed from frozen sources; unchanged
engine libraries retain matching source inputs. Both mobile exports match the
same cut. See the [source hashes](source-provenance.json) and
[localisation comparison](mobile-locale-frozen-comparison.json).

All 56 minor-release check commands pass with no source drift. Six initial
commands encountered relocated compiler-cache paths and passed with private
caches. The Hot Seat mobile check rejected a fixture path through a checkout
symlink. It passed with identical files in a local directory. The [initial audit](initial-audit.json), [input hashes](inputs.json),
[reruns](audit-reruns.json) and [validation summary](validation.json) retain the
results. Raw local logs are retained under `.build/release-2.2.1` and are not
published because system frameworks can log private local account metadata.

The shared source gate passes 531 tests. The release-tool suite passes 95 tests;
83 focused clock, artwork and pause checks, nine SwiftUI widget appearance
renders, thirteen hostless UIKit checks and ten localisation/picker tests pass.
All eight draft language packs pass structure checks; human translation review
remains open. The release-note page was inspected at its top and bottom; native
checks cover three window sizes, scrolling and the Continue target.

## Acceptance limits

The owner confirmed the repaired desktop widget before requesting this release.
No new foreground launch or actual updater relaunch was run. Automated windows
stayed offscreen and all test audio stayed muted. Foreground focus, physical
input, minimum-OS and Intel hardware, calendar permission, live cloud, physical
Duo and AltStore device acceptance retain their recorded limits.

Classic and The Tribes remain Complete. Chronicles and NeoLemmix remain Beta.
Mobile Journey remains Classic-only. Full-corpus route and source-fidelity
closure remain open under the [existing scope](../../ReleaseScope.md).
