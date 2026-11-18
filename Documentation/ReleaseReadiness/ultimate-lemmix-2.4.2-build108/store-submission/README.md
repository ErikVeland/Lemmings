# Ultimate Lemmix Store submission handoff

Checked 19 November 2026. Version 2.4.2, build 108 on Mac, iOS and tvOS.

All three refreshed Store packages are signed and passed Apple's local package
analysis with zero product errors. The final exports completed after the owner
restored Xcode credential access.
No build has been uploaded, processed by App Store Connect, submitted for review
or published. These are preparation artifacts, not a completed submission.

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

App Store Connect sign-in is verified. The owner selected one listing for
Mac, iOS and tvOS: Apple ID `6836347807`, main bundle ID
`academy.glasscode.ultimatelemmix`. All three platform records exist. Mac version
2.4.2 listing text, Games/Puzzle category and content rights are saved. Release
is manual. The iOS and tvOS records still show version 1.0. The signed-in
browser accepts text but button presses do not take effect. An owner handoff
is pending for the filled iOS draft. Do not treat version 2.4.2 as saved there.
The new record has no Game Center leaderboards configured yet.

The website is live at `https://lemmings.glasscode.academy` with valid HTTPS.
All ten public routes, redirects, deployed hashes and the 404 response passed.
Mac support and marketing URLs are saved. Other Store URL fields remain open.
The contact address `erik@veland.au` is verified from the published GenErik DJ
site. App Review contact fields still need completion, including a phone number.

The [Store account checklist](StoreAccountChecklist.md) records source-backed
privacy, rating, encryption and Game Center requirements. These answers are
prepared but are not saved account declarations.

Complete these account and publication items before submitting:

1. Verify and save version 2.4.2 for iOS and tvOS. Complete age rating,
   price/availability and the review contact, including its telephone number.
2. Configure the required Game Center leaderboards for the shared listing.
3. Save the verified website URLs in the remaining App Store Connect fields.
4. Confirm deployed retention and provider logging against the privacy notice
   and App Store privacy responses. Complete the encryption determination.
5. Review the [listing draft](StoreListing.en-AU.json), screenshots and
   [App Review notes](AppReviewNotes.md).
6. Upload the signed packages. Require successful Apple processing before
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

[Unified mobile packaging instructions](UnifiedListingMobile.md) cover current source archives,
resource-bundle signing, local exports and exact verification. The build wrapper
keeps Store compilation flags separate from overridable resource locations.
[Account and service details](AccountAndServices.md) retain the original signing
investigation. The [unified identity record](UnifiedListingMobile.md) supersedes
their earlier mobile main IDs and records the current profiles and capabilities.

Ultimate Lemmings and Ultimate Lemmix retain separate product markers, release
branches, versions and release histories. Shared source changes pass through
`main` and are checked for parity before pushing.
