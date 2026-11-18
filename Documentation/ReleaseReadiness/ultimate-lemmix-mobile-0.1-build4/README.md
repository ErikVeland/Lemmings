# Ultimate Lemmix mobile build 4 evidence

Build 4 is an unsigned resource and icon refresh for iOS and tvOS. It reuses
the four build 3 binaries. All 190 Swift and package inputs match the recorded
compilations for each platform. Binary and original archive hashes also match.
Compiler settings and asset identifiers remain unchanged. The project adds
four data-folder resource phases and uses build number 4.

Xcode 27.2 (27B52) compiled four fresh asset catalogues. Each app contains
1,959 approved resource files. The generated metadata, icons, resources,
archive CRCs and every packaged file hash passed. Independent final refresh
audits passed for both platforms. No Swift source was recompiled.

| Product | Archive bytes | Evidence |
| --- | ---: | --- |
| iOS device | 23,922,365 | [Build evidence](ios/build-evidence.json) |
| iOS Simulator | 24,899,325 | [Final audit](ios/final-audit.log) |
| tvOS device | 29,099,689 | [Build evidence](tvos/build-evidence.json) |
| tvOS Simulator | 30,097,745 | [Final audit](tvos/final-audit.log) |

[Final audit data](final-audit.json) records the exact archive paths and hashes.
The products remain under `.build/ultimate-lemmix-ios-build4` and
`.build/ultimate-lemmix-tvos-build4`. Each folder contains an unsigned device
IPA, a Simulator ZIP, a device archive and the full refresh evidence.

The [mobile packaging tests](mobile-packaging-tests.log) passed 21 checks,
including ten refresh guards. The [historical product pins](historical-build3-products.json)
cover 20 build 3 archive, app and evidence files. Their bytes remain unchanged.
Earlier build 3 compilation evidence remains in
[`ultimate-lemmix-0.1-build3`](../ultimate-lemmix-0.1-build3).

The asset compiler reported unavailable CoreSimulator services and runtimes.
All four asset compilation commands still exited successfully. No Simulator
or physical device gameplay ran. The mobile UI remains Classic-only.
UIKit rendering, touch, Siri Remote focus, controller input, VoiceOver,
network permission and thermal acceptance remain open.

The requested project icon still needs rights review. Signing, provisioning,
TestFlight and App Store review remain release gates. These artefacts are not
signed, uploaded or ready for submission.
