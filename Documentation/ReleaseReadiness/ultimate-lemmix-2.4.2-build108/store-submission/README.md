# Ultimate Lemmix Store submission handoff

Checked 18 November 2026. Version 2.4.2, build 108 on Mac, iOS and tvOS.

All three local Store packages are signed and pass Apple's local package
analysis. No build has been uploaded, processed by App Store Connect, submitted
for review or published.

## Packages

| Platform | Final package | Verification |
| --- | --- | --- |
| Mac, Apple silicon and Intel | `mac/Export/Ultimate Lemmix.pkg` | [Mac receipt](mac-store-package.json) |
| iPhone and iPad | `ios-store-export/UltimateLemmixIOS.ipa` | [iOS receipt](ios-store-package.json) |
| Apple TV | `tvos-store-export/UltimateLemmixTVOS.ipa` | [TV receipt](tvos-store-package.json) |

The paths above are relative to
`/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118`.
The `Handoff` folder contains copies of the final packages, checksums and review
material. A Downloads shortcut points to that folder.

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
`restoration/Ultimate-Lemmix-Restoration-20261118.zip`.
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

App Store Connect browser sign-in is verified. The new Ultimate Lemmix Mac record
has Apple ID `6836347807` and bundle ID `academy.glasscode.ultimatelemmix`.
The initial details-page error resolved on retry. Version 2.4.2 listing text,
Games/Puzzle category and content rights are saved. Release is manual.
The new record has no Game Center leaderboards configured yet.
The stored Xcode account already completed provisioning and local Store export.
The owner is choosing one cross-platform listing or separate platform listings.
A single listing requires matching mobile app identifiers and new mobile packages.

Complete these account and publication items before submitting:

1. Verify the platform app records, build numbers, Game Center boards, age
   rating, price/availability and review contact.
2. Approve and publish the [privacy notice](PrivacyNotice.md). Supply its public
   URL and contact. Confirm deployed retention and provider logging against the
   source-backed declarations.
3. Review the [listing draft](StoreListing.en-AU.json), screenshots and
   [App Review notes](AppReviewNotes.md). Complete the encryption determination.
4. Upload the signed packages and require successful Apple processing before
   selecting each platform build for review.

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

[Mobile packaging instructions](MobilePackages.md) cover current source archives,
resource-bundle signing, local exports and exact verification. The build wrapper
keeps Store compilation flags separate from overridable resource locations.
[Account and service details](AccountAndServices.md) identify the six executable
IDs and required capabilities.

Ultimate Lemmings and Ultimate Lemmix retain separate product markers, release
branches, versions and release histories. Shared source changes pass through
`main` and are checked for parity before pushing.
