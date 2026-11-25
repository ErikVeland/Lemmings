# Ultimate Lemmix Store submission handoff

Current account state: all 359 leaderboards and four sets are configured, and
the Mac encryption declaration is complete. Build 108 is valid and attached on
all three platforms. Nothing has been submitted for review. China compliance
remains open. See [20 November verification](AccountConfiguration108.md).

Checked 19 November 2026. Version 2.4.2, build 108 on Mac, iOS and tvOS.

All three refreshed Store packages are signed and passed Apple's local package
analysis with zero product errors. The final exports completed after the owner
restored Xcode credential access.
Apple processed build 108 and it is attached to all three platform drafts.
No app or Game Center component has been submitted for review or published.

## Packages

| Platform | Current Handoff package | Verification |
| --- | --- | --- |
| Mac, Apple silicon and Intel | `Mac/Ultimate Lemmix 2.4.2 (108).pkg` | [Mac receipt](mac-store-package.json) |
| iPhone and iPad | `iOS/Ultimate Lemmix 2.4.2 (108).ipa` | [Unified mobile receipt](unified-mobile-package-results.json) |
| Apple TV | `Apple TV/Ultimate Lemmix 2.4.2 (108).ipa` | [Unified mobile receipt](unified-mobile-package-results.json) |

Paths start at `/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/Handoff`.
All three refreshed packages replaced the earlier exports after exact verification.
Both mobile packages use the shared main ID
`academy.glasscode.ultimatelemmix`, with their distinct extensions retained.
The separate-ID mobile packages are superseded and remain outside the handoff
in the dated build archive.
The `Handoff` folder contains the signed packages, checksums and review material.
A Downloads shortcut points to that folder.

Fresh archives use source `1ac19c638e3f62dd48f7d4dedf17b285b961b079`.
Their development signatures, resources and entitlements passed local checks.
See [Mac archive refresh](MacSourceRefresh.md) and
[mobile archive refresh](MobileRenderRefresh.md).
Exports and exact package verification passed for all three archives.
Earlier exports remain in the dated build archive under `Superseded`.

The Mac package contains both architectures, all six shared libraries and Desk
Clock widget. iOS retains its Desk Clock widget; TV retains Top Shelf. Every
executable uses a Store distribution signature and matching profile. CloudKit
uses Production, and TV push uses its production entitlement. Codeless resource
bundles have valid same-team signatures, with their exact contents also sealed
by the enclosing distribution signature. Apple's local analyser reports no
product errors.

The exact resource audits include current feature metadata, localization,
verified hints and rescue targets, Lix media, the project logo, pixel lettering
and the three authored starter puzzles. Original game assets, original fonts
and third-party remix collections are outside the installed Store packages.

## Preserved features and evidence

The application retains HD effects, stone controls, Journey, Hot Seat, saved
runs, hints, replays, imports and the platform extensions. The deliberate Apple
TV flash-effect exception remains unchanged.

[Source equivalence](ReplaySourceEquivalence.json) preserves 609 rescue
witnesses and 350 hint entries. The simulation sources match their certified
baseline. No new replay run or new solvability claim is made.

[Mac presentation evidence](MacPresentation.json) verifies the opening screen
before quit and a running starter level with all six actors visible while
Original remains selected. All 42 recorded input targets fit in the window.
The capture ran offscreen, muted and with isolated storage. Raw captures and
RGB-only submission PNGs are retained outside the repository.

[Mobile presentation evidence](MobilePresentation.json) records actual Home
captures on iPhone, iPad and Apple TV. The PNGs have accepted dimensions and no
alpha channel. These are clean Debug simulator captures, not physical-device
gameplay or service acceptance. All temporary capture devices were removed.

Automated test suites, broad replay audits and test-running release audits were
skipped under the non-engine release policy. Required builds, signing,
provisioning, inventories, archive checks and package analysis ran. There is no
Sparkle feed or separate notarisation step for these App Store packages.

## Restoration bundle

The separate transport file is
`Restoration/Ultimate-Lemmix-Restoration-20261118.zip`.
It contains 23,591 resources, including the local levels, artwork, original
font and 495 music variants. Native import and a separate-process reopen passed.
Every archive member's size, checksum and CRC passed. See the
[bundle receipt](RestorationBundle.json).

Extract the ZIP. Select its `Resources` folder in **Restore original assets**.
iPhone and iPad use Files. Apple TV uses the displayed private local-network
transfer page. Keep the source ZIP for recovery if TV caches are purged.

The bundle is ready for local import. The owner confirms redistribution permission
for the original game assets and included third-party recordings. Supporting
permission records have been offered but are not yet attached or reviewed.
[Owner decisions](OwnerDecisions.json) records that confirmation. The verified ZIP
is unchanged and retains its earlier packaging-time rights status. It has not
been uploaded to archive.org or another host.

## Remaining submission work

App Store Connect has one Ultimate Lemmix listing. Apple ID `6836347807`
and bundle ID `academy.glasscode.ultimatelemmix` apply to all three platforms.
Mac, iOS and tvOS each have a saved 2.4.2 draft with manual release.
The review contact, review notes, marketing and support URLs are saved.
The price is free. All 175 regions are selected, subject to Apple’s eligibility
and compliance checks. App Store Connect shows a 13+ rating.

Apple confirmed publication of the four App Privacy responses. The privacy and
privacy choices URLs and the Apple TV privacy text are saved. The live website
passed checks on all ten public routes, redirects, deployed hashes and the 404
response.

[Mac refresh evidence](MacGameCenterNamespace.md) and
[mobile refresh evidence](MobileGameCenterRefresh.md) cover the re-signed
packages. They use independent Lemmix Game Center identifiers. Apple has all four sets and all 359 localised boards.
Component review and signed service acceptance remain open.

Package uploads, screenshot uploads and build selections are complete.
The Mac encryption declaration is complete and matches iOS and tvOS. The owner confirmed
that mainland China filing records exist. Obtain the records, then complete
the applicable App Compliance fields. Keep the restoration publication separate.

[Hosted service evidence](HostedServices.md) confirms public endpoints respond.
It does not establish signed cross-device save recovery, Game Center board
availability or physical-device input, import and widget acceptance. Those
limits remain recorded separately; lower-priority platform checks do not hold
the Mac package.

## Reproduction

Use `Scripts/build-ultimate-lemmix-app-store.sh --automatic-export` for Mac,
with the dedicated external build directory, team, signing identity and matching
development profiles. The script preserves source records, verifies all
resources, signs nested bundles, archives and exports a local Store package.

[Unified mobile packaging instructions](UnifiedListingMobile.md) cover current source archives,
resource-bundle signing, local exports and exact verification. The build wrapper
keeps Store compilation flags separate from overridable resource locations.
[Account and service details](AccountAndServices.md) retain the original signing
investigation. The [unified identity record](UnifiedListingMobile.md) supersedes
their earlier mobile main IDs and records the current profiles and capabilities.

Ultimate Lemmings and Ultimate Lemmix retain separate product markers, release
branches, versions and release histories. Shared source changes pass through
`main` and are checked for parity before pushing.
