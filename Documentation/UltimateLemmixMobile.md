# Ultimate Lemmix for iOS and tvOS

Ultimate Lemmix has separate iPhone/iPad and Apple TV application targets.
Both use the authored starter campaign, CC0 Lix artwork and the full licensed
Lix soundtrack. Six tracks use CC0 and two use CC BY 4.0.
Starter play needs no game folder, account or download.

| Platform | Project | Bundle identifier | Minimum OS |
| --- | --- | --- | --- |
| iPhone and iPad | `Apps/UltimateLemmixIOS/UltimateLemmixIOS.xcodeproj` | `academy.glasscode.ultimatelemmix` | iOS 16 |
| Apple TV | `Apps/UltimateLemmixTVOS/UltimateLemmixTVOS.xcodeproj` | `academy.glasscode.ultimatelemmix` | tvOS 16 |

Both display the name **Ultimate Lemmix**. Current candidate metadata is 2.4.2,
build 108. The 0.1 records below are historical. The existing
Ultimate Lemmings iOS target remains separate. The
[macOS edition](UltimateLemmix.md) shares the Lemmix App Store app identity.
Each platform retains its own target and signed package.
The requested project icon is shared across these editions. Its character
rights review remains open.

## Content and controls

The three starter puzzles teach walking, floating and climbing through the
normal Classic simulation. Their scenes use actual Lix brick, earth and wood
tiles, animated hatches and exits. They need no original graphics, sound
samples or destruction masks.

Settings offers Lix artwork and music. The starter always uses Lix.
After a Classic import, the player can choose the original artwork.
This changes presentation, not the simulation, targeting or saved-run identity.
The Lix animations approximate some Classic actions.

The HUD uses actual Lix skill and transport graphics, checkbox artwork and
button colours. Text uses the bundled Lix UI font and its separate licence.
Touch and remote input targets retain the shared layout geometry.

iPhone and iPad retain touch selection, pan, zoom and the shared pixel HUD.
Apple TV adds focus navigation and Siri Remote controls. Left and Right choose
an actor. Select assigns the selected skill. Down moves to the HUD. Menu opens
the pause actions. Play/Pause toggles pause. Extended controllers can also
select actors and skills, assign, move the camera and open pause actions.

Player-facing mobile content covers Classic only. Lemmings 2 and Lemmings 3
still need mobile import and rendering. These builds do not present the
sequels as playable.

## Player-owned files

On iPhone and iPad, **Import Classic** opens the system folder picker.
The app copies a validated Classic DOS folder into its own storage.
The mobile BYO helper contains the Classic contract and platform instructions.
It contains no original data or executable plug-in.

On Apple TV, **Import Classic** opens a temporary local transfer page.
Scan the QR code or enter the displayed address on a phone or computer.
Select the Classic folder, then choose **Import to TV**. The browser transfers
the selected regular files directly to the TV. The same page offers the
asset-free helper ZIP.

The TV service starts only while the import page is open. A random session
address expires after ten minutes. Closing the page or entering the background
stops new transfers. Native validation finishes from retained staging files,
and a process-wide lease prevents another installation from overlapping it.
The service bounds headers, requests, file paths, counts and bytes. It rejects
duplicate paths, foreign web origins, incomplete files and out-of-order chunks.
The native importer verifies the staged game and preserves a working prior
import if replacement fails.

The initial TV transfer supports private IPv4 networks. IPv6-only transfer
support remains a release gate. The local transfer uses HTTP with a temporary
unguessable address. It does not contact a content host or download original
game data.

tvOS keeps imported data and checkpoints in Caches. The system can purge these
between launches, so the player may need to import again. The bundled starter
remains available. Apple describes this storage behaviour in
[its tvOS storage guidance](https://developer.apple.com/videos/play/wwdc2023/10256/).

## Build and audit

Prepare the pinned assets and source helper:

```sh
zsh Scripts/prepare-alternative-assets.sh
zsh Scripts/prepare-lix-font.sh
zsh Scripts/prepare-byo-integration.sh
```

Build the independent device and Simulator review products:

```sh
zsh Scripts/build-ultimate-lemmix-ios.sh --resources-only
zsh Scripts/build-ultimate-lemmix-ios.sh
zsh Scripts/build-ultimate-lemmix-tvos.sh
```

The first command refreshes the shared generated resources after source or
metadata changes. Both platforms verify that same inventory before compiling.

The scripts select full Xcode, use project-local caches and audit the exact
resource allowlist. Their default outputs include the current build number,
for example `.build/ultimate-lemmix-ios-build4` and
`.build/ultimate-lemmix-tvos-build4`. Use `--output-dir` for a separate review
folder when you need to preserve an existing build. Each platform produces an unsigned device
`.xcarchive`, an unsigned review `.ipa`, a Simulator ZIP and build evidence.
An unsigned IPA needs signing before installation. It is not a TestFlight or
App Store upload.

Use the same build wrappers with `--audit` to compare completed products,
source hashes and review archives after a full compilation.

For a resource-only update, `Tools/Build/refresh_mobile.py` can reuse an earlier
verified binary. It requires unchanged Swift and package inputs, unchanged
compiler settings, matching Xcode and SDK versions, and an empty output folder.
It compiles fresh icon catalogues and records binary reuse explicitly. A code
change requires a full compilation. Audit the current resource refresh with:

```sh
python3 -B Tools/Build/refresh_mobile.py ios --audit
python3 -B Tools/Build/refresh_mobile.py tvos --audit
```

Run focused resource and transfer checks:

```sh
zsh Scripts/check-ultimate-lemmix-mobile-resources.sh
zsh Scripts/check-local-import-transfer.sh
```

The transfer suite uses the offscreen, muted runner and a loopback listener.
It tests synthetic bytes only. Environments that prohibit local listeners
need normal execution permission for that specific check.

## Build 4 validation, 17 November 2026

Build 4 refreshes resources, metadata and the shared project icon. It reuses
the four build 3 binaries. All 190 Swift and package input records still match
for each platform. Binary hashes, compiler settings and asset identifiers also
match. Xcode 27.2 compiled fresh device and Simulator icon catalogues.
This was a source-bound resource refresh, not a new Swift compilation.

Each app contains 1,959 approved resource files. Resource inventories,
generated metadata, icon files, archive CRCs and packaged file hashes passed.
Independent refresh audits passed for [iOS](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build4/ios/final-audit.log)
and [tvOS](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build4/tvos/final-audit.log).
The complete mobile packaging suite passed 21 tests.

| Platform | Output folder | Device review archive | Simulator review archive |
| --- | --- | --- | --- |
| iOS | `.build/ultimate-lemmix-ios-build4` | `Ultimate-Lemmix-ios-0.1-build4-unsigned.ipa` | `Ultimate-Lemmix-ios-0.1-build4-simulator.zip` |
| tvOS | `.build/ultimate-lemmix-tvos-build4` | `Ultimate-Lemmix-tvos-0.1-build4-unsigned.ipa` | `Ultimate-Lemmix-tvos-0.1-build4-simulator.zip` |

The [release evidence](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build4/README.md)
retains source and binary pins, archive hashes and the exact validation limits.
All 20 pinned build 3 review archives, app files and evidence files remain unchanged.

The project icon remains subject to rights review. The mobile UI remains
Classic-only. No Simulator runtime or physical device test ran. UIKit rendering,
touch, remote focus, VoiceOver, network permission and thermal acceptance remain
open. These unsigned review artefacts need signing before installation.
TestFlight and App Store submission have not occurred.

## Build 3 validation, 17 November 2026 (historical compilation)

The device and Simulator products passed for both platforms with the Lix HUD
buttons and bundled UI font. The new folders are `.build/ultimate-lemmix-ios-build3`
and `.build/ultimate-lemmix-tvos-build3`. Font data and the full separate notice
are included in each exact resource inventory.

Source, bundle, identity and archive audits passed:
[iOS](ReleaseReadiness/ultimate-lemmix-0.1-build3/ios/build-evidence.json),
[tvOS](ReleaseReadiness/ultimate-lemmix-0.1-build3/tvos/build-evidence.json),
[combined audit](ReleaseReadiness/ultimate-lemmix-0.1-build3/final-audit.json).
The shared font tests also check complete proportional-text fitting.
These are unsigned review artefacts. UIKit rendering, focus, touch, physical
devices and distribution signing remain acceptance gates.

## Build 2 validation, 17 November 2026

The Lix scene update compiled and passed final audits for iOS device,
iOS Simulator, tvOS device and tvOS Simulator. Each product retains the same
platform identity and 1,431 approved resources. The mobile explosion state
now uses the same related Lix animation as Mac; a real bomber transition
checks its rendered pixels.

The new output folders are `.build/ultimate-lemmix-ios-lix-scene-build2` and
`.build/ultimate-lemmix-tvos-lix-scene-build2`. They contain unsigned device
IPAs, Simulator ZIPs, logs and exact source/build records. Retained records:
[iOS](ReleaseReadiness/ultimate-lemmix-0.1-build2/ios/build-evidence.json),
[tvOS](ReleaseReadiness/ultimate-lemmix-0.1-build2/tvos/build-evidence.json),
[combined final audit](ReleaseReadiness/ultimate-lemmix-0.1-build2/final-audit.json).

Headless checks cover all three 2× scenes, actor anchors, logical targeting,
reticle coordinates, reversible artwork selection, unchanged checkpoints,
normal starter solutions and the bomber animation.
[Packaged-core results](ReleaseReadiness/ultimate-lemmix-0.1-build2/packaged-core-mobile.log).
These are shared-core checks on Mac, not UIKit, Simulator or physical-device
acceptance. No Simulator runtime was launched. Device interaction, signing and
App Store submission remain open.

## Build 1 validation and release limits

The earlier build 1 records below describe the character-only renderer.
All four unsigned Release builds passed on 17 November 2026 with Xcode 27.2
(27B52): iOS device, iOS Simulator, tvOS device and tvOS Simulator.
Each product contains arm64 code and 1,431 approved resource files totalling
15,191,969 bytes. Both platform icon catalogues compiled fully.
Archive integrity and all packaged file hashes passed.
Final read-only [iOS](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/ios/audit.log)
and [tvOS](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/tvos/audit.log)
audits also passed.

| Review artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| iOS unsigned IPA | 17,280,023 | `646cc98ff0edfe7c477f17d028309da4f6f00395f3f62d01163f06d5238911b2` |
| iOS Simulator ZIP | 18,267,696 | `d52e65b76ae8f940a2df9212ee09220d3c5c3ec833aa1cd7c12b81c023b0a31f` |
| tvOS unsigned IPA | 17,330,551 | `92ea48760d2a50e50cbe6beb1acb83c8ed7569d0aca86d8352d55a14cdfe7d59` |
| tvOS Simulator ZIP | 18,325,353 | `2329d4a5166027fefb9d50cb7ce984942c66e459d71bfe3a3df8d368d393066b` |

The [iOS build record](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/ios/build-evidence.json)
and [tvOS build record](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/tvos/build-evidence.json)
retain 212 and 240 input hashes. Both snapshots matched after compilation.
The records identify the dirty checkout at
`1d080a935a765c772664c79a0e4f8b18831cdd99`. No release tag or upload was
created. The earlier macOS review ZIP retained its original SHA-256.

The mobile-only BYO helper is 2,447 bytes, SHA-256
`777722d0a3d031a6dc5ca716fe11d46e8c04b96e2515f51c6fa51a171f7573bc`.
Four resource/helper rejection tests passed. Neither mobile product includes
original commercial data, fan remixes or Sparkle.
[Resource check results](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/resource-checks.log).

All 17 mobile-core tests pass across the existing and clean-content suites.
They render Lix without original files and complete all three starter puzzles
through normal commands. They also cover presentation changes, checkpoint
stability and failed-import rollback.
[Results](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/mobile-regressions.log).

The local transfer checks cover the browser page, helper download, token and
origin checks, ordered chunks, native import callbacks and slow-install
closure/restart behaviour. These checks pass without a TV or audible playback.
[Results](ReleaseReadiness/ultimate-lemmix-mobile-0.1-build1/tv-transfer.log).

The workstation has iOS and tvOS 27.2 SDKs. Both platform icon catalogues
compile. No Simulator runtimes are installed, and the signing-identity check
found no valid identities on 17 November 2026.

Simulator launch, rendered UIKit states, physical touch, Siri Remote focus,
controller input, local-network permission, IPv6-only transfer, VoiceOver,
thermal behaviour and audible playback remain acceptance gates. Distribution
signing, provisioning, privacy and rights review, TestFlight and App Store
review remain release gates.
