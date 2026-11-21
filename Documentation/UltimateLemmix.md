# Ultimate Lemmix

Ultimate Lemmix uses the full Ultimate Lemmings 2.4.2 application. Its baseline is
`b294d3b7c298f549aad5faa36f92ba9bf23b7529`, which contains the published build 106
source. The current source fingerprint is
`c9abe4e0aab0410ab43923a4c9b8c5cced89f3e0792f091740b97b5be9c99d93`.
A [source-equivalence record](ReleaseReadiness/ultimate-lemmix-2.4.2-build108/store-submission/ReplaySourceEquivalence.json)
retains 609 rescue witnesses and 350 hint entries from the original fingerprint
`9a246f97fd42930d53c273a4bb9c45800f0379fd7326f7c65518d484ebfeeea5`.
The simulation sources match that baseline. Reviewed differences add import,
starter content and presentation; they do not establish new replay evidence.

Historical 0.1 Lemmix builds 1–4 used the older 1.8 checkout. They are not the
full-game baseline and do not establish current feature parity.

## Same game, selectable resources

The full menus, engines, Journey, collections, profiles, Hot Seat, recovery,
records, hints, localisation, cloud interfaces and Desk Clock remain in the
application. Lix supplies the default artwork and music. The shared resource
preparer includes all eight tracks from the pinned Lix soundtrack. Six use CC0.
Mike Spanner’s “Earthen Energy” and “Winter” use CC BY 4.0, with credits in the app.
The three independent starter puzzles use ordinary native game-data files and
the existing engine. They provide first-launch play without original game data.

## Bundled content policy

Include every available non-official level, recording, graphic and font with
redistribution permission and support in Ultimate Lemmix. Check each pack’s
dependencies too. A fan level can require official scenery, and a public-domain
composition can have a separately licensed recording. Original game assets
remain available through player import.

The owner approved the complete fan-level selection for the Store update:
487 Classic packs (5,051 levels) and all 120 NeoLemmix Introduction levels.
The Store packager includes the reviewed level files from
`Resources/UltimateLemmix/FanCatalogue.zip`. Its checksum pins the selection.
The Classic packs retain the three pack-specific special graphics needed for
geooPk0, geooPk1 and Mon0lith. The earlier personal-preview inventory describes
the unfiltered source archives.

The build also requires the pinned `FanRuntime.zip` input. Place it in
`.build`, or set `ULTIMATE_LEMMIX_FAN_RUNTIME` to its path. It supplies the
Classic sprites, terrain and object data under `FanRuntime`, and the
NeoLemmix styles under `NeoLemmix/styles`. Classic campaign discovery uses
the separate `Ports` folder so fan artwork does not advertise official campaigns.
The optional restoration download remains available for additional content.

### Lemmings Forums sources

Use the forum’s maintainer and creator posts to establish the terms for each
asset. Use the NeoLemmix pack index to find the original posts and downloads.
The index mixes original packs with conversions and gives no common licence.
[NeoLemmix pack index](https://www.lemmingsforums.net/index.php?topic=7011.0)

| Source | Published terms and release scope |
| --- | --- |
| [Lix upstream licence](https://github.com/SimonN/LixD#licensecopyingpublic-domain) and [Simon’s forum clarification](https://www.lemmingsforums.net/index.php?topic=7618.0) | The upstream CC0 dedication covers levels, graphics and sound effects. Music and the font have separate terms in the pinned notice. The current resource preparer already includes the eight licensed tracks, Lix graphics and the licensed font. |
| [MandelSoft’s FL Studio arrangements](https://www.lemmingsforums.net/index.php?topic=3921.0) | The creator permits credited use in level packs and as replacement music. The post describes sources from the Windows game and another creator’s MIDI work. Resolve third-party rights and verify App Store scope track by track. |
| [WillLem’s NeoLemmix Lemminas pack](https://www.lemmingsforums.net/index.php?topic=4679.0) and [Lemminas Origins](https://www.lemmingsforums.net/index.php?topic=6695.0) | The creator permits credited reuse of specified media in community packs or levels. The composition credits distinguish original tracks from tracks with samples or other writers. Origins also contains official levels and variants of them. The media reuse statement does not clear the full archive. |
| [Raymanni’s NeoLemmix tilesets](https://www.lemmingsforums.net/index.php?topic=3279.0) | The creator shares these styles for NeoLemmix. The post gives no wider distribution terms. Use the verified Lix versions where the Lix licence covers them. |

The pinned Lix 0.10.36 source has 859 single-player files, 15 tutorial files and
990 network level files with native level headers. Ultimate Lemmix cannot
read the Lix format or run its simulation.

On 20 November 2026, the local Classic review matched all 487 candidate ZIPs
to their pinned hashes and searched 27 readable documentation members for
licence and redistribution terms. It found no grant in those files. This
check does not establish what an author may have granted elsewhere.
[Classic catalogue policy](../Resources/AlternativeAssets/community-levels-policy.json)

Track findings against the [remix rights inventory](../Resources/AlternativeAssets/fan-remix-rights.json)
and [Apple’s intellectual property requirements](https://developer.apple.com/app-store/review/guidelines/#intellectual-property).

Importing assets changes the resource source. It does not install missing
features or another game executable. The shared resource provider, original
renderers and current controls resolve the selected artwork.

With complete owned assets and **Original** selected, Classic, L2, L3 and
NeoLemmix use their existing native rendering paths. Lix pose substitutions are
disabled. The independent starter always uses Lix because it has no original
sprite bank.

The Lix skin has presentation limits. Some L2/L3 actions use neutral Lix poses.
Owned L2/L3 scenery, tools and effects remain native. NeoLemmix custom actions,
gliding and zombie/neutral states retain their native art. Lix body colours do
not reproduce every native athlete tint. These substitutions do not change
skills, input, targeting or simulation rules.

**Restore original assets** accepts an existing preservation application or a
prepared resource folder. It retains supported artwork, fonts, music, sounds,
campaigns and level libraries in a validated private data bundle. Embedded
cursor pictures can be recovered from the selected local application without
executing it. Standalone executable payloads are excluded.

A raw DOS game folder restores that game's data. It cannot supply Macintosh
interface artwork, Amiga media or soundtrack collections absent from that
folder. Those require their actual source assets or a complete prepared pack.

The importer preserves previous installations and re-merges owned assets with
the current application resources after an update. App identity, privacy,
service configuration, current engine stamp and proof metadata stay app-owned.
The [Game Assets release](https://github.com/ErikVeland/Lemmings/releases/tag/ultimate-lemmix-game-assets-1)
contains the original campaigns and standard music. To download it, you must hold a
valid licence for the original Lemmings game on at least one platform. In builds with
**Download game assets**, choose **Agree and download** to confirm your licence.
The app then downloads, verifies and installs the 253 MB pack. Build 110 uses the
extracted folder through **Restore original assets**. Settings offers 18 optional
soundtrack libraries after restoration.

## Build and acceptance

Ultimate Lemmix is a [separate project and release](SharedPublishing.md) on
`release/ultimate-lemmix`. Its own manifest controls its version and build counters.
Shared engines and features stay in sync with Ultimate Lemmings through `main`.
New builds use the [Ultimate Lemmix app icon](../Resources/UltimateLemmix/AppIcon/README.md)
on Mac, iPhone, iPad and Apple TV. The following records describe build 108.

The local Mac candidate is 2.4.2 build 108. It uses the current Mac architecture
and the complete frontend. Its ad hoc signature passes strict verification.
At the owner's explicit request, focused muted offscreen checks verify complete
import, live activation and cold restoration. They compare menu/control contracts,
native pixels, content identities, checkpoints and Hot Seat queue ownership.
The [build 108 record](ReleaseReadiness/ultimate-lemmix-2.4.2-build108/README.md)
records the results and limits. Broad suites, corpus audits, Intel and
notarisation remain outside this local manual build.

The separate full iOS and tvOS targets compile against the device SDKs as
2.4.2 build 108. They include the current Desk Clock widget and Top Shelf
extension. The actual GameArt package compiler receives the Store condition.
These local outputs are unsigned. Device gameplay, import, input, audio,
extensions and service acceptance remain unverified. No Simulator ran.
The retained [iOS SDK record](ReleaseReadiness/ultimate-lemmix-2.4.2-build108/ios-device-sdk.json)
and [tvOS SDK record](ReleaseReadiness/ultimate-lemmix-2.4.2-build108/tvos-device-sdk.json)
identify the source, resources, compiler conditions, outputs and limits.

The separate mobile projects are `Apps/UltimateLemmixIOS` and
`Apps/UltimateLemmixTVOS`. Use `Apps/UltimateLemmixSupport/build.sh` with `ios` or
`tvos` and the required Xcode build arguments. The wrapper passes
`Store.xcconfig` to application and Swift package targets. A compile-time marker
rejects GameArt built without the Store condition. The prepared mobile profile
contains an exact data inventory so imports retain resources without copying
the application executable, frameworks or extensions.

The Store widget reads selected owned clock artwork from its App Group. The
app publishes validated immutable artwork and then replaces the selection
atomically. A separate native-render check covers this resource boundary.
Signed group access and hosted WidgetKit reload still require device acceptance.

The manual Mac build retains the existing local save location. Quit build 107
before opening build 108. Automated checks used separate temporary storage.

The personal build 108 used the Ultimate Lemmings project icon. Its character rights required
separate review. App Store signing, service provisioning, privacy and rights clearance
remain release gates. This local build is not an approved Store release.

## Store preparation on 18 November 2026

The build 108 Store profile used the complete frontend and shared modules. It
included the authored starters, pinned Lix media, a CC0 Lix-derived icon, the
project Lemmix logo and the shared Ultimate Lemmings pixel font. The font
package includes the two faces and counter glyphs. Other original game media
stay in the separate restoration bundle. Imported original artwork
can replace the fallback after validation. Starter scenes retain their Lix
artwork even when the player selects Original for restored campaigns.

Game Center, cloud capabilities, the Mac/iOS Desk Clock widgets and Apple TV
Top Shelf remain enabled. The privacy manifests declare the observed hosted
identifiers, gameplay content and optional interaction analytics. The two
products have separate release histories and version-history build gates.

Use the [Store submission dossier](ReleaseReadiness/ultimate-lemmix-2.4.2-build108/store-submission/README.md)
for current signed outputs and remaining acceptance. Earlier local receipts
above describe personal test builds; they do not establish Store clearance.

### Shared pixel font input

Store resource preparation reads the verified Ultimate Lemmings font banks from
`.build/mac-artwork/export/lemmings`. For a separate checkout, set
`ULTIMATE_LEMMIX_PIXEL_FONT_DIR` to the installed Ultimate Lemmings app’s
`Contents/Resources/MacArtwork/lemmings` directory. Use the same setting when
preparing and auditing the resources. The packager checks the glyphs and metrics
and copies only the font banks. The shared licence covers both apps and their
App Store media.
