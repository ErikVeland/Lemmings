# AltStore Classic

Add this source in AltStore Classic on iPhone or iPad:

```text
https://raw.githubusercontent.com/ErikVeland/Lemmings/main/altstore.json
```

Open **Sources**, tap **+**, and paste the address. The source offers Ultimate
Lemmings 2.2.1 build 21 for iOS 16 or later. Its IPA is attached to the
[canonical 2.2.1 release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.2.1).
The [source JSON](../altstore.json) and app icon also stay in this repository.

AltStore Classic re-signs the IPA with the installing player's Apple Account.
The original app and Desk Clock widget are included. The source declares the
union of their signing entitlements and calendar privacy descriptions.
Account limits, app refresh and extension installation follow
[AltStore Classic's rules](https://faq.altstore.io/altstore-classic/app-ids).
An AltStore device installation, widget acceptance, iCloud propagation and
Game Center access have not been verified. Re-signing changes the signing
identity; do not assume access to the original team's cloud containers.

This source uses AltStore Classic's IPA distribution. AltStore PAL needs a
separate Apple-notarised Alternative Distribution Package and marketplace
setup; the TestFlight export is not that package. See the official
[Classic distribution](https://faq.altstore.io/developers/distribute-with-altstore-classic),
[source format](https://faq.altstore.io/developers/make-a-source) and
[PAL distribution](https://faq.altstore.io/developers/distribute-with-altstore-pal)
instructions.

## Release maintenance

Keep the source URL stable. Add future versions at the start of `versions`.
Use an unencrypted device IPA, its exact version, build, minimum OS and byte
size. Read permissions from the exported app and every extension; do not copy
only the project's entitlement file. Do not remove permissions from the
source to conceal a mismatch with the IPA.

Upload each IPA to this repository's app release before updating `altstore.json`.
Keep existing downloads and the Mac update feed. Verify the public source,
icon and complete IPA download, including the release asset's SHA-256 digest.
Commit the source, documentation and receipt without unrelated workspace work.
The [2.2.1 release record](ReleaseReadiness/2.2.1-build98/README.md) retains the
frozen source identity and AltStore publication checks.
