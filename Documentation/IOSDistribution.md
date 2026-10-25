# iOS distribution

Updated 25 October 2026, Brisbane.

The owner requires distribution across iOS sideloading stores. Treat each active
store as release work. A compatible source, a downloadable IPA, a catalogue
listing and a verified device installation are separate milestones.

## Current release

AltStore Classic offers **2.2.2 build 33**, published on 24 October. The live
[source](https://raw.githubusercontent.com/ErikVeland/Lemmings/main/altstore.json)
was read again on 25 October. GitHub's public release metadata confirms the
[IPA](https://github.com/ErikVeland/Lemmings/releases/download/v2.2.2/UltimateLemmings-2.2.2-build33-ios.ipa),
its 207,620,836-byte size and SHA-256:

```text
c413b14de8dbc9f67c75dcc1fd45049498e9b7eb3607341d02d1f7dc88cd6f60
```

The [publication receipt](ReleaseReadiness/2.2.2-build99/altstore-publication.json)
records a complete public download on 24 October. The 25 October check read the
live source and release metadata. It did not download or install the IPA again.
The [25 October check receipt](ReleaseReadiness/IOSDistribution-2026-10-25.json)
records that boundary and the source hash.
The local source and installation guide still named 2.2.1 before this update.
The live source already contained 2.2.2. This update restores that exact live
source locally and retains both older versions.

The [IPA validation](ReleaseReadiness/2.2.2-build99/altstore-verification.json)
records an unencrypted device binary, the widget, signatures and permissions.
Re-signing, widget installation, iCloud and Game Center remain unverified on a
physical device. TestFlight Beta Review is separate from marketplace notarisation.

## Coverage and next actions

The entries below describe project evidence, not a claim that we have audited
every store account. No submission receipts or live catalogue links for the
other stores were found in the release records reviewed on 25 October.

| Channel | Current project evidence | Next action and completion evidence |
| --- | --- | --- |
| AltStore Classic | Live source and released IPA verified. Device install remains open. | Install, launch, refresh and update on a supported device. Retain the client/OS version and result. |
| SideStore | Its [official documentation](https://docs.sidestore.io/docs/advanced/app-sources) accepts the existing AltStore source. | Verify source import, installation, refresh and update. Track the community catalogue separately. |
| Feather | Its [official site](https://feather.khcrysalis.dev/) supports AltStore sources and IPA import. | Verify import, signing, installation and update using the existing source. Record widget handling and the signing capabilities. |
| SideStore Community Source | [Submission guidelines](https://github.com/SideStore/Community-Source#readme) exist. No accepted listing is recorded. | Prepare device screenshots, icon, metadata, entitlements and requested download hash. Submit through its documented contribution route and retain the accepted listing. |
| AltStore PAL | No marketplace connection, notarisation or Alternative Distribution Package receipt is recorded. | Follow the PAL sequence below, then verify the published source and installation. |
| Aptoide / AppArena | [iOS submission](https://docs.connect.aptoide.com/docs/ios-app-submission) uses Aptoide Connect and App Store Connect, with separate marketplace tokens. No submission is recorded. | Register the app, connect both marketplaces, provide the notarised build and required metadata, and retain review decisions and live listings. |
| Epic Games Store | [Distribution](https://store.epicgames.com/en-US/distribution) and [mobile content requirements](https://cdn2.unrealengine.com/epic-games-store-content-guidelines-f8accc43356e.pdf) are documented. No submission is recorded. | Establish publisher access, confirm current iOS onboarding, provide the notarised build and required store assets, and verify a live listing. |
| Skich Store | [Store policy](https://skich.app/trust-safety) describes developer eligibility. No submission is recorded. | Complete publisher onboarding and the store's current game submission requirements. Retain acceptance and a live listing. |
| Onside | Its [developer service](https://developer.onside.io/) and [console documentation](https://docs.onside.io/console) describe iOS publishing. No submission is recorded. | Establish console access, connect the app and submit its notarised build and metadata. Verify the listing and installation. |
| appdb | [Official publishing](https://appdb.to/news/529) is available through its Publisher Area. No project listing is recorded. | Verify developer ownership, submit the canonical IPA and metadata, and retain the approved listing. |
| Signulous | [Custom IPA upload](https://www.signulous.com/) is documented. No catalogue listing or device acceptance is recorded. | Verify installation from the canonical IPA. Establish its separate catalogue submission route before claiming store availability. |
| Sideloadly | [IPA installation](https://sideloadly.io/) is documented. This is an installer route. | Verify the canonical IPA's installation, launch, refresh and update. |
| LiveContainer | [IPA import](https://github.com/LiveContainer/LiveContainer#installing-apps) is documented. This is a container route. | Verify launch, saves, file import and updates. Record extension and Apple-service limitations before claiming compatibility. |
| Scarlet, ESign, GBox, KSign, TrollStore and other installers/catalogues | No project-specific source, submission or device evidence is recorded. | Confirm each current official distribution route, source schema and supported OS before preparing an adapter or claiming support. Test the canonical IPA where supported. |
| mobivention | Its [marketplace description](https://mobivention.com/presse-en-2/mobivention-app-marketplace-successfully-launched/?lang=en) focuses on business distribution. No project listing is recorded. | Confirm whether a public consumer game is eligible. Record an explicit eligibility decision. |
| Setapp Mobile | [Discontinued on 16 February 2026](https://support.setapp.com/hc/en-us/articles/25494771202716-Setapp-Mobile-sunset). | Retain this closure as the reason no submission proceeds. |

This inventory is open. Add newly identified stores with an official developer
route, an evidence-backed state and a next action. Record unavailable or
ineligible channels explicitly.

## AltStore PAL sequence

Use the [official PAL distribution instructions](https://faq.altstore.io/developers/distribute-with-altstore-pal).

1. Register the App Store Connect Developer ID through AltStore's REST API.
2. Add the returned marketplace token in App Store Connect and select this app.
3. Configure marketplace notifications or retain a manual build-processing step.
4. Submit the app for Apple notarisation, or retain its qualifying App Store approval.
5. Obtain the processed Alternative Distribution Package from AltStore.
6. Host the complete package with its directory hierarchy and file bytes intact.
7. Publish and verify a PAL source using the notarised package's actual identifiers.
8. Enable [source discoverability](https://faq.altstore.io/developers/source-discoverability) and verify the resulting listing.
9. Verify installation and update on a supported physical device.

Keep PAL metadata in a separate source from `altstore.json`. Do not add a
marketplace identifier to the Classic source: SideStore warns that notarised
source fields can prevent a Classic source from being added. A TestFlight IPA
cannot substitute for an Alternative Distribution Package.

The account connection, notarisation and package-hosting steps have no retained
completion evidence. Do not describe this as waiting for Apple until there is
an actual submitted notarisation request.

## Release requirements

Keep the source, issues and downloads in `ErikVeland/Lemmings`. Keep `main` as
the default branch and preserve the stable Classic source URL. Publish additional
download-only releases without replacing the latest app release.

For each app release:

1. Publish the unencrypted IPA on the canonical app release.
2. Validate all contained app and extension identities, minimum OS and permissions.
3. Verify the public file size and complete download SHA-256.
4. Prepend the version to the source and retain existing versions.
5. Update each accepted catalogue and marketplace, using its required package.
6. Record each channel's version, listing URL, submission identifier and actual state.
7. Retain install/update results and explicit limits for each tested client.

For device acceptance, check Classic, The Tribes and Chronicles launch and save
recovery, Hot Seat Ready handovers, and retry/continue controls. Record widget
installation, calendar access, iCloud and Game Center separately. All automated
checks must remain headless and muted under the repository's test rules.

Use the existing release metadata and artwork as submission inputs. Read
[third-party notices](../THIRD_PARTY_NOTICES.md) and the
[handover dependencies](HandoverDependencies.md) before completing any store's
content-ownership declarations. A native source-code licence does not establish
rights to the bundled game data.
