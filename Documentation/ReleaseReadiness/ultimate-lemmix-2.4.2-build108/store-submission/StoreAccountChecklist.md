# Ultimate Lemmix Store account checklist

Source audit: 19 November 2026. Candidate: 2.4.2, build 108.
App Store listing: `6836347807`, bundle ID `academy.glasscode.ultimatelemmix`, shared by Mac, iOS and tvOS.

These are proposed answers and configuration requirements. This audit did not
save or verify answers in App Store Connect. Treat the entries below as unsaved
until the account operator confirms them. Package export and website publication
are complete according to the current release handoff. Earlier dossier claims
that the website is unpublished are historical.

## Proposed App Privacy answers

Select **Yes, we collect data from this app**. The three main-app privacy
manifests contain the following declarations:

| App Store data type | Linked to the user | Purpose | Tracking |
| --- | --- | --- | --- |
| User ID | Yes | App Functionality | No |
| Device ID | Yes | App Functionality | No |
| Gameplay Content | Yes | App Functionality | No |
| Product Interaction | No, subject to the processing check below | Analytics | No |

Sources: [Mac privacy manifest](../../../../Resources/UltimateLemmix/PrivacyInfo.xcprivacy),
[iOS privacy manifest](../../../../Apps/UltimateLemmixIOS/PrivacyInfo.xcprivacy) and
[tvOS privacy manifest](../../../../Apps/UltimateLemmixTVOS/PrivacyInfo.xcprivacy).

- Cloud storage receives encrypted saves, library and device identifiers, authentication material and update metadata. Encryption does not make this a no-collection app. See [CloudLibraryArchive.swift](../../../../Sources/LemmingsAppCore/Records/CloudLibraryArchive.swift) and [CloudLibraryTransport.swift](../../../../Sources/LemmingsAppCore/Records/CloudLibraryTransport.swift).
- Community rankings receive pseudonymous player credentials, initials, scores, run identifiers and action replays. Shared initials and eligible replays are public. See [HostedRankings.swift](../../../../Sources/LemmingsAppCore/Records/HostedRankings.swift).
- Opt-in counts describe fixed gameplay and soundtrack events. Their payload excludes player, device, profile and replay identifiers. Requests use an ephemeral session without cookies. See [AnonymousTelemetry.swift](../../../../Sources/LemmingsAppCore/Privacy/AnonymousTelemetry.swift).
- Calendar events are displayed locally. The reviewed path does not add them to telemetry or cloud archives. Calendar permission alone does not establish collection. See [DeskClockEventReader.swift](../../../../Sources/LemmingsMobileCore/DeskClockEventReader.swift).
- No advertising identifier use, advertising SDK or dedicated third-party crash-reporting SDK was found in the reviewed candidate paths.

Use `https://lemmings.glasscode.academy/privacy` for the privacy policy and
`https://lemmings.glasscode.academy/privacy/choices` for privacy choices.
The maintained text is [privacy.html](../../../../Website/content/privacy.html)
and [privacy-choices.html](../../../../Website/content/privacy-choices.html).

**Owner confirmation:** confirm that app-service hosting and network logs do
not associate optional telemetry with a user or device. Review any additional
provider processing before confirming Product Interaction as unlinked. Review
support correspondence against Apple's optional-disclosure criteria. Do not
infer that optional gameplay sharing is exempt from disclosure.

The notice distinguishes daily counter rows, lifetime totals, public records,
encrypted cloud snapshots and maintenance copies. Do not promise complete
deletion when removal affects only the live ranking service.
See [Apple's privacy definitions and optional-disclosure rules](https://developer.apple.com/app-store/app-privacy-details/).

## Age-rating questionnaire

The questionnaire describes available features and content. The three starter
levels alone do not establish answers for every supported imported route.
Do not choose a target age first and alter the answers to obtain it.

| Question | Source-backed finding | Proposed treatment |
| --- | --- | --- |
| User-generated content | Public player initials and action replays are distributed through community rankings. | Yes. |
| Contests | Hosted and Game Center boards let players compete for rankings. | Present. Owner must confirm frequency. |
| Cartoon or fantasy violence | Supported engines contain character deaths, explosions, bomber actions and the nuke action. | Present. Owner must assess frequency and intensity. |
| Guns or other weapons | Imported Lemmings 2 supports bazookas and mortars. Imported Lemmings 3 supports bombs and grenades. | Do not answer None without considering these supported routes. |
| Messaging and chat | No direct text, voice or video chat implementation was found in the reviewed Swift sources. | No, subject to the final feature review. |
| Advertising | No paid advertising implementation was found. | No. |
| Unrestricted web access | No embedded unrestricted browser implementation was found. External support links do not establish unrestricted browsing inside the app. | No, subject to the final interface review. |
| Parental controls and age assurance | No dedicated parental controls or declared-age implementation was found. Sharing consent is not age assurance. | No. |
| Gambling, simulated gambling and loot boxes | No wagering or paid random-item system was found. | None. Leaderboard competition remains a separate contests answer. |

Evidence: [HostedRankings.swift](../../../../Sources/LemmingsAppCore/Records/HostedRankings.swift),
[GameCenterScores.swift](../../../../Sources/LemmingsAppCore/Records/GameCenterScores.swift),
[NeoLemmixSimulation.swift](../../../../Sources/NxlvKit/NeoLemmixSimulation.swift),
[Lemmings2Runtime.swift](../../../../Sources/NxlvKit/Lemmings2Runtime.swift) and
[Lemmings3Runtime.swift](../../../../Sources/NxlvKit/Lemmings3Runtime.swift).

**Owner confirmation:** assess frequency for contests, cartoon violence and
weapons. Review available artwork, level titles, narrative and imported/community
content for profanity, horror, suggestive themes and other content descriptors.
This source audit does not establish those frequency answers or a Kids Category
age band. Confirm the moderation and reporting arrangements for public content.
Use [Apple's current age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/).

## Encryption determination

The app **uses encryption**. It uses HTTPS through system networking,
CryptoKit AES-GCM for saved libraries and device links, CryptoKit HKDF/SHA-256,
and CommonCrypto PBKDF2-SHA256 for password-derived keys. These are Apple
operating-system implementations, not a proprietary cipher implementation.

The source supports the **encryption limited to the Apple operating system**
determination. Apple's table states that this category needs no encryption
documentation upload in App Store Connect. Confirm the final bundled dependencies
and applicable distribution requirements before saving the declaration.
Do not answer that the app uses no encryption.

The [iOS Info.plist](../../../../Apps/UltimateLemmixIOS/Info.plist) and
[tvOS Info.plist](../../../../Apps/UltimateLemmixTVOS/Info.plist) already set
`ITSAppUsesNonExemptEncryption=false`. The reviewed Mac Info.plist omits that key,
so its build may require the determination in App Store Connect. An omitted key
does not imply non-exempt encryption.

Sources: [CloudLibraryArchive.swift](../../../../Sources/LemmingsAppCore/Records/CloudLibraryArchive.swift),
[CloudLibraryTransport.swift](../../../../Sources/LemmingsAppCore/Records/CloudLibraryTransport.swift),
[Apple's documentation table](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)
and [export-compliance determination](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/).

## Game Center configuration

1. Confirm Game Center for each submitted platform version in the Lemmix listing.
2. Compare the account's board IDs and formats with the bundled configuration.
3. Configure the required localisations, score units, limits, sorting and sets.
4. Submit the required Game Center components for review with the release.
5. Record signed sign-in, score submission, offline retry and account-change acceptance separately.

[leaderboards.json](../../../../Resources/GameCenter/leaderboards.json) enables
Game Center and contains 178 ranked Classic configurations. The prepared
[board manifest](../../../../Resources/GameCenter/app-store-connect-boards.json)
contains 359 boards: 178 rescue boards, 178 fastest-clear boards and three career
boards. Its four sets contain 100, 100, 100 and 59 boards.

The career IDs are `ul.v1.career.stars`, `ul.v1.career.cleared` and
`ul.v1.career.three_star`. Rescue and career scores descend. Fastest-clear scores
ascend and use positive milliseconds. Keep the exact IDs and score rules.
The catalogue contains no starter-level entries. A starter-only review cannot
demonstrate those imported-content level boards.

**Account verification remains open.** The setup manifest still names
`academy.glasscode.lemmings`. Use its board definitions for comparison, but do
not apply its product identity to Lemmix. Historical Lemmings activation receipts
do not prove configuration for app `6836347807`. Do not group or merge the two
products without a separate owner decision.

Apple permits 500 boards with sets, with at most 100 boards in each set.
The prepared configuration fits those limits. Components require review before
public availability. See [leaderboard sets](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboard-sets/),
[version configuration](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-an-app-version-for-game-center)
and [component review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components).

## Separate Mac CloudKit caveat

The current [Mac Info.plist](../../../../Resources/UltimateLemmix/Info.plist)
sets `CloudLibraryCloudKitEnabled=false`. Both mobile Info.plists set it to true.
[mac_store.py](../../../../Tools/Publication/mac_store.py) checks the packaged
Mac Info.plist against that source. An entitlement that permits CloudKit does
not establish that this runtime provider is enabled.

Keep the Mac runtime flag separate from Game Center and hosted encrypted saves.
Confirm the intended Mac provider configuration before claiming active Mac
CloudKit in review notes. This audit did not change the flag, manifests,
packages, Apple account or hosted services.
