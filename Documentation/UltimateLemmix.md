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
application. Lix supplies the default artwork and six licensed music tracks.
The three independent starter puzzles use ordinary native game-data files and
the existing engine. They provide first-launch play without original game data.

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
contains the original campaigns and standard music. In builds with **Download game assets**,
one action downloads, verifies and installs the 253 MB pack. Build 110 uses the extracted
folder through **Restore original assets**. Settings offers 18 optional soundtrack libraries after restoration.

## Build and acceptance

Ultimate Lemmix is a [separate project and release](SharedPublishing.md) on
`release/ultimate-lemmix`. Its own manifest controls its version and build counters.
Shared engines and features stay in sync with Ultimate Lemmings through `main`.
Its current candidate metadata is 2.4.2 build 108 on all three platforms.

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

The requested existing project icon is retained. Its character rights require
review. App Store signing, service provisioning, privacy and rights clearance
remain release gates. This local build is not an approved Store release.

## Store preparation on 18 November 2026

The Store profile uses the current complete frontend and shared modules. It
includes the authored starters, pinned Lix media, a CC0 Lix-derived icon, the
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
