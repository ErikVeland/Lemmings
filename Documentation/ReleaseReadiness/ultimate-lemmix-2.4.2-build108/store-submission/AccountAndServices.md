# Ultimate Lemmix account and service gates

Candidate: 2.4.2, build 108 on Mac, iOS and tvOS. Checked 18 November 2026.
This record distinguishes local source checks from Apple account and device acceptance.
It does not establish submission readiness, an uploaded build, or a published release.

## Signing and account evidence

The local keychain has two valid signing identities: Apple Development and
Developer ID Application for Erik Veland. The cached paid Individual team is
`54WU29TRTY`. No local Apple Distribution, Mac App Distribution or Mac Installer
Distribution identity was found. Neither standard provisioning-profile folder
contained a profile for any Ultimate Lemmix bundle identifier at inventory time.
Lemmings profiles have different App IDs and cannot sign Lemmix.

These local gaps do not prove that distribution is blocked. Xcode can use
[cloud-managed distribution certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/).
The iOS and tvOS app and extension targets use automatic signing with team
`54WU29TRTY`. A live isolated Mac build subsequently authenticated with the retained Xcode
account and obtained the two Mac development profiles listed below. The mobile archives obtained matching development profiles, and both final
mobile exports subsequently passed distribution signing and package analysis.
Mac distribution export remains a separate check.

No App Store Connect connector, `asc` CLI, `fastlane` CLI, standard API-key folder,
or configured ASC key environment variables were found. The browser inventory
exposed no controllable browser. Xcode retains an account reference and team
cache. That cache alone was not proof of authentication. The later live Mac provisioning
request succeeded and produced profiles with current creation dates. No
credentials were extracted. App Store Connect metadata access remains unverified.

Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for this candidate.
The system selection points to the separately installed beta:

| Installation | Xcode build | Device SDKs | Swift |
| --- | --- | --- | --- |
| `/Applications/Xcode.app` | 27.1, `27A9275` | macOS 27.0, iOS 27.1, tvOS 27.0 | 6.4, `swiftlang-6.4.0.34.1` |
| `/Applications/Xcode-beta.app` | 27.2 beta, `27B5019j` | macOS, iOS and tvOS 27.2 | 6.4, `swiftlang-6.4.0.34.1` |

Apple's [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)
allow Xcode 27.1 RC for App Store delivery from 5 October. The installed 27.2
beta is distinct from the final 27.2 release. Record the actual compiler and SDK
in each archive receipt.

## Live Mac provisioning result

The isolated project at `/private/tmp/ultimate-lemmix-provisioning-7vo0994p`
uses the actual Mac app and widget IDs, team and capability requirements.
The first automatic build succeeded. Its app profile omitted the shared group.
An explicit App Groups capability and `REGISTER_APP_GROUPS=YES` obtained corrected
profiles for both targets, without changing unrelated product identities.
Apple documents this requirement for
[provisioned Mac app groups](https://developer.apple.com/documentation/xcode/accessing-app-group-containers).

| Target | Development profile UUID | Verified authorisation |
| --- | --- | --- |
| Mac app | `241ba4c4-dbb7-4386-b157-13c6fa020759` | Shared app group, Game Center, shared iCloud and ubiquity containers, Production and Development cloud environments |
| Mac widget | `5e81edf9-d512-4432-bcd4-2b7123cde481` | Shared app group |

Profiles are installed under
`~/Library/Developer/Xcode/UserData/Provisioning Profiles/UUID.provisionprofile`.
The usable identity is `Apple Development: Erik Veland (T93G24W53E)`.
These are development profiles. They do not establish Store distribution signing,
leaderboard configuration, CloudKit runtime acceptance or an App Store record.
The isolated binaries are provisioning probes only. They are not release products
and must never be uploaded. Logs stay beside that temporary project.

## Live mobile provisioning result

Both initial device archives completed with automatic signing. The retained
Xcode account issued these development profiles, each expiring 18 November 2027:

| Target | Development profile UUID |
| --- | --- |
| iOS app | `6f79991b-e76f-4697-9c70-ae31f068389b` |
| iOS widget | `86cc6919-8b86-4eb0-8cf5-9cb3fe510a78` |
| tvOS app | `1b0a5f0f-dc21-4a85-9fa6-558fdf1a5c32` |
| Top Shelf | `8bc3cf73-de34-4581-a6a2-13f3bfdbe7d6` |

All four profiles authorise the shared app group. Main-app profiles authorise
Game Center and the shared iCloud container. The iOS profile also authorises
ubiquity storage. The tvOS development profile uses development push service.
Distribution export must replace that with production push service. These
results prove live provisioning access, not App Store metadata completion.

## Live mobile distribution result

Both final mobile exports completed with the retained account and cloud-managed
Apple Distribution signing. No local distribution private key was extracted.
The final app and extension signatures use team `54WU29TRTY`, with Production
cloud and tvOS push entitlements. Their Store profiles expire 10 October 2027.

| Target | Store profile UUID |
| --- | --- |
| iOS app | `5482c7a5-69fd-407d-b9a3-c96ada8f6cd8` |
| iOS widget | `88486ca9-eaee-458b-8bfa-e2577f3914e6` |
| tvOS app | `0909d776-3c3a-4430-ac96-66dc9b1ecbb0` |
| Top Shelf | `06732da4-990a-411d-b2d8-dfb5822afe19` |

The final exports pass strict executable and nested-resource signature checks,
exact prepared-resource hashes, privacy-manifest comparison and Apple's local
package analysis with no product errors. See [MobilePackages.md](MobilePackages.md)
for commands, resource-signing details and the canonical output directories.
The output directories contain the exact IPA hashes in `verification.json`.

These results establish local distribution-package readiness. They do not prove
uploaded-build processing, App Store record completeness or device acceptance.
An earlier tvOS export logged a transient Store configuration request failure,
`-24169`, while still completing its export. No metadata was changed and no
build was uploaded.

## Required product identities

Each executable needs its own matching profile. Preserve these identifiers:

| Target | Bundle identifier | Required services |
| --- | --- | --- |
| Mac app | `academy.glasscode.ultimatelemmix` | Sandbox, shared app group, Game Center, CloudKit, iCloud Documents, calendar access, selected-file access, network client |
| Mac widget | `academy.glasscode.ultimatelemmix.DeskClockWidget` | Sandbox, shared app group, calendar access |
| iOS app | `academy.glasscode.ultimatelemmix.ios` | Shared app group, Game Center, CloudKit, iCloud Documents |
| iOS widget | `academy.glasscode.ultimatelemmix.ios.DeskClockWidget` | Shared app group |
| tvOS app | `academy.glasscode.ultimatelemmix.tvos` | Shared app group, Game Center, CloudKit, push notifications |
| Top Shelf | `academy.glasscode.ultimatelemmix.tvos.TopShelf` | Shared app group |

The app group is `group.academy.glasscode.lemmings`. The shared iCloud container
is `iCloud.academy.glasscode.lemmings`. Existing Lemmings profiles establish that
these service identifiers exist in cached account material. The live Mac profiles now establish those assignments for the two Mac IDs.
Mobile development profiles also contain those assignments. Distribution signing
and runtime acceptance remain separate.

Require these profile and signed-entitlement values:

- `com.apple.security.application-groups`: the shared app group for all six targets.
- `com.apple.developer.game-center`: `true` for each main app.
- `com.apple.developer.icloud-container-identifiers`: the shared iCloud container for each main app.
- `com.apple.developer.icloud-services`: `CloudKit` on all main apps, plus `CloudDocuments` on Mac and iOS.
- `com.apple.developer.ubiquity-container-identifiers`: the shared container on Mac and iOS.
- `com.apple.developer.icloud-container-environment`: `Production` in distribution signatures.
- `aps-environment`: `production` for the tvOS distribution app. The corresponding Mac push key, when requested, is `com.apple.developer.aps-environment`.
- App and team identifiers must match the executable and `54WU29TRTY`. Distribution signatures must not enable `get-task-allow` or the Mac equivalent, `com.apple.security.get-task-allow`.

Retain Mac sandbox file bookmarks, user-selected read/write access, network
client access and calendar access. Do not remove features to satisfy an incomplete
profile. App-group membership and iCloud-container assignments require their
own configuration, beyond checking the capability box. See Apple's
[capability configuration](https://developer.apple.com/help/account/identifiers/enable-app-capabilities)
and [Store provisioning procedure](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/).

## Automatic signing route

1. Archive each mobile target with automatic signing and `-allowProvisioningUpdates`.
2. Keep the archive's normal Apple Development signing selection.
3. Export with `method=app-store-connect`, `destination=export`, `signingStyle=automatic` and `teamID=54WU29TRTY`.
4. Set `iCloudContainerEnvironment=Production` and `manageAppVersionAndBuildNumber=false`.
5. Pass `-allowProvisioningUpdates` to the export command.
6. Inspect every embedded profile, signed entitlement, bundle identifier and version in the exported package.
7. Retain the complete export log and Apple's validation result.

Xcode 27.1 documents that automatic export of a manually signed archive can
create profiles and cloud signing certificates. It does not register App IDs or
modify their capability settings. A manually assembled Mac archive therefore
needs the correct registered IDs and service assignments first.

If Apple rejects the retained account session, refresh the existing account in
Xcode Settings > Accounts. An authorised ASC API key is an alternative. Do not
revoke existing certificates or replace unrelated product profiles. No upload
or submission follows from a successful local export.

## Source-backed privacy declarations

All three app Info.plists configure hosted cloud saves, community rankings and
optional count sharing on `glasscode.academy`. A no-collection claim is incorrect
for the full-feature candidate. The Mac privacy manifest now declares:

| Data category | Linked | Purpose | Source evidence |
| --- | --- | --- | --- |
| User ID | Yes | App functionality | Cloud-library UUID, pseudonymous rankings player and initials |
| Device ID | Yes | App functionality | Random installation identity used for cloud device slots |
| Gameplay Content | Yes | App functionality | Encrypted saved progress, rosters, shared journeys, scores and action replays |
| Product Interaction | No, subject to deployed logging verification | Analytics | Opt-in installation, active-day, level outcome, rescue and soundtrack counters |

Tracking is false. No advertising identifier or advertising SDK was found in the
reviewed paths. Keep iOS and tvOS declarations consistent with these shared
features. Their initial manifests already declared the first three categories. The
candidate now adds Product Interaction to both mobile manifests.

`AnonymousTelemetry.swift` sends fixed events only after count-sharing consent.
Its payload excludes player, device, profile and replay identifiers. It uses an
ephemeral session without cookies. Server source retains daily aggregates for
90 days. This is source evidence, not a current inspection of the deployed
proxy, hosting provider or retention configuration.

`HostedRankings.swift` sends player initials, a pseudonymous credential, scores,
run identities and action files. If no explicit player choice exists, record
sharing follows the count-sharing setting. Public replays contain gameplay
commands and proof metadata. They do not contain level assets or video in the
current sharing flow. The source provides removal of shared player records.
Do not describe all sharing as anonymous counters.

`CloudLibraryArchive.swift` encrypts library contents with AES-GCM.
`CloudLibraryTransport.swift` uses private iCloud storage and authenticated HTTPS
fallback. Hosted storage receives opaque ciphertext, library/device identifiers
and update metadata. The app derives password-based keys with PBKDF2-SHA256 and
HKDF. Encryption does not remove the need to disclose hosted storage.

`DeskClockEventReader.swift` reads the next calendar event after system permission.
The reviewed calendar path displays event data locally. It does not add calendar
data to the cloud archive or telemetry payload. Imported game files remain local
unless the player explicitly transfers them to another device. Do not declare
calendar upload merely because calendar access is requested.

The reviewed required-reason APIs use file timestamps (`C617.1`, `3B52.1`),
elapsed time (`35F9.1`) and app-only defaults (`CA92.1`). The observed app-group
artwork exchange uses files. It does not justify adding an app-group UserDefaults
reason without an actual shared-defaults call. Inspect the final app, frameworks
and extensions for their privacy manifests and actual API use.
See Apple's [required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

These are proposed ASC privacy responses, not saved account answers. Apple's
[privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
require disclosure of collected data even when collection is optional, unless
all optional-disclosure conditions apply. Confirm provider processing before
claiming that telemetry cannot be linked to a person or device.

## Privacy notice and encryption gates

The reviewed repository sources did not identify a verified public Ultimate
Lemmix privacy-policy URL. No live ASC metadata was accessible. Before submission:

1. Verify the public policy URL in each Store record and in the app.
2. Describe optional counts separately from public initials, scores and action replays.
3. Describe encrypted cloud storage, library/device identifiers and recovery methods.
4. Explain sharing controls, removal requests, server retention and backup retention.
5. Identify Apple services and hosting-provider processing accurately.
6. Align the policy, ASC answers and all packaged privacy manifests.

Do not claim that all data stays on the device, that the app collects no data,
or that all shared data is anonymous. Existing `CloudProgress.md`,
`HostedRankings.md` and `GameCenterSetup.md` describe hosted storage and proxy
limits. They do not prove the current published notice or deployment.

The mobile Info.plists currently set `ITSAppUsesNonExemptEncryption=false`.
The app uses HTTPS and operating-system CryptoKit/CommonCrypto services.
Record the applicable exemption using Apple's
[encryption determination](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/).
Do not answer that the app uses no encryption. Do not infer export clearance
from the existing Boolean alone.

## Service and resource acceptance

The initial audit found these gaps, now corrected in the candidate source:

- Mac `Info.plist` disabled CloudKit and Game Center progress. Its entitlements omitted iCloud and Game Center.
- `prepare_lemmix_base.py` forced the packaged leaderboard configuration to `enabled=false`.
- The old `store_resources.py` privacy gate required an empty collection declaration.

The mobile privacy manifests now also include Product Interaction. Inspect the
final packages to confirm all source corrections reached the signed products. An enabled JSON flag and valid
signature do not establish configured leaderboards or working cloud services.
`GameCenterActivation.json` refers to Lemmings app `6810873426`, not Lemmix.
`GameCenterIOSSetup.json` refers to Lemmings and records pending verification.
Neither is acceptance evidence for these Lemmix App IDs.

Confirm the following without replacing the shared save or service identities:

- Lemmix Store records exist for the three exact bundle IDs and build 108 is available for upload.
- Game Center is enabled for the candidate versions and the configured leaderboard IDs exist for each app or intended group.
- Production CloudKit authorises each Lemmix app and supports `ULPrivateLibrary` in private zone `ULPrivateLibraryV2`.
- Mac/iOS iCloud Documents and Game Center saved-game bridges retain compatible progress.
- tvOS uses CloudKit/hosted saves. GameKit saved games are unavailable on tvOS.
- Isolated reopen, offline/reconnect and cross-device acceptance retain players, turns, queues and completion records.
- Clean packages contain only approved media, current provenance and the three playable starter levels.
- Player-owned imports remain data-only, with local file selection on Mac/iOS and temporary local-network transfer on TV.

Historic CloudKit schema receipts exist under the Lemmings 2.4-build104 record.
They do not prove current Lemmix entitlement access or physical-device behaviour.
No automated tests, foreground test windows, live save mutations or audible
checks were run for this dossier.

## App Review handoff

Prepare a separate Store version record for each required platform. Confirm the
app name, category, age-rating answers, support URL, public privacy URL, screenshots,
review contact, content rights and encryption response. Do not copy the Lemmings
Apple app IDs or claim previous Lemmings service acceptance for Lemmix.

Proposed review notes:

> Ultimate Lemmix includes three playable starter puzzles and licensed fallback
> artwork and music. Original game media is not included. Optional import accepts
> player-selected data and does not download or execute original applications.
> Local play does not require a hosted account. Cloud saves synchronise
> automatically. Game Center and community record sharing are optional.
> Count-sharing consent also explains
> public initials, scores and action replays. Calendar permission supplies the
> next-event display in Desk Clock. Apple TV imports use a temporary address on
> the player's local network.

Use these notes only after the final clean-package inventory confirms them.
Apple requires the chosen build and required metadata before
[submission for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/).
Package creation, upload processing, review and public availability remain
separate acceptance states.
