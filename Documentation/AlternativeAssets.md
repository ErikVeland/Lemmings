# Alternative asset preparation

Prepared and integrated 12 November 2026. This work supplies Lix graphics and
selected CC0 music. Settings → Graphics offers Lix artwork across the three
native games. The separate [Ultimate Lemmix edition](UltimateLemmix.md) adds an
open starter campaign and a local BYO importer.

## Prepare and check

Run the repository preparation script:

```sh
zsh Scripts/prepare-alternative-assets.sh
```

The first run downloads pinned upstream sources. Later runs reuse verified
local caches. Changed downloads fail their recorded size or SHA-256 checks.
The preparation tools do not install dependencies or play audio.

Check the prepared resources and combined archive without downloading:

```sh
zsh Scripts/check-alternative-assets.sh
```

The output is `.build/alternative-assets/open-alternative.zip`. It includes
graphics, playback music, unchanged music sources, credits, licences, source
records, previews and a file-hash manifest. It excludes the existing fan-remix
audio. Generated resources stay outside Git and can be rebuilt from the
tracked tools and source records.

The separate preparation scripts are
`Scripts/prepare-lix-alternative.sh` and
`Scripts/prepare-alternative-music.sh`. Each also supports `--verify`.

## Source and licence scope

The graphics source is Lix revision
`f1e805048fe439a4a0e9cc650c613713ababac8b`. The source locks are
[`lix-source.json`](../Resources/AlternativeAssets/lix-source.json) and
[`music-sources.json`](../Resources/AlternativeAssets/music-sources.json).

Lix's [pinned copying notice](https://github.com/SimonN/LixD/blob/f1e805048fe439a4a0e9cc650c613713ababac8b/doc/copying.txt)
dedicates sprites, menu icons and tileset graphics to the public domain through
CC0. It also covers the menu music and `music/minim-mobius` tracks. The prepared
music set selects those six tracks. These are independent Lix compositions,
not remixes of the Lemmings score.

The CC0 graphics pack excludes the separately licensed font and `music/rubix`
tracks. A separate font pack now supplies Lix's unchanged DejaVu Sans Condensed
Bold font, with its full Bitstream Vera and Arev notices. Run
`zsh Scripts/prepare-lix-font.sh` to prepare it. The
[font source lock](../Resources/AlternativeAssets/lix-font-source.json) records
the exact font and notice hashes. This font is not CC0. The
[official font licence](https://dejavu-fonts.github.io/License.html) permits
distribution with the required notices.

The full upstream notice and creator credits accompany the prepared pack. Asset
permission does not grant rights to Sony's branding or original campaigns.

## Existing fan-remix audit

[`fan-remix-rights.json`](../Resources/AlternativeAssets/fan-remix-rights.json)
records 34 existing recordings and 66 source/playback files with hashes. It
keeps composition, arrangement and recording permission separate.

| Recordings | Finding for the proposed App Store pack |
| --- | --- |
| 32 MandelSoft arrangements | Conditional. Creator terms permit credited level packs and replacement soundtracks. App distribution scope and upstream rights remain unresolved. |
| 1 AmiGamer recording | Pending. Public redistribution requires agreement under the distributor's FAQ. Conflicting older terms are recorded. |
| 1 CoLD SToRAGE recording | Excluded pending permission. The release page reserves rights. |
| 0 existing remixes | Verified for inclusion in the proposed App Store pack. |

A public-domain composition does not itself clear a later arrangement or
recording. The existing catalogue also contains modern game compositions.
Use the recorded creator evidence and per-track review before changing an
inclusion status. This audit does not change existing Mac music packaging.

## Integration boundary

The shared selection replaces Classic terrain, objects and characters without
changing engine geometry. Lemmings 2 and 3 retain imported terrain and objects.
Some sequel actions use a neutral Lix pose where no matching animation exists.

The interface adapter uses Lix's actual skill, transport and checkbox sheets.
Button backing follows Lix's own CC0 drawing rules and palette. The personal
preview uses the original bitmap lettering for the full HUD, including skill
captions, quantities, status, speed and zoom badges. Clean builds use the
separately licensed Lix font. Font choice does not depend on imported level art.
Shared transport buttons keep their actions and accessibility names. Their
input regions match the visible controls.

The shared scene renderer samples actual Lix brick, earth, wood and steel
tiles. It draws animated hatches, exits, water, fire and traps at 2× Classic
resolution. Source transparency keys and sprite-sheet separators are removed
during decode. Scene presentation reads the simulation masks and trigger
positions; it does not replace them with Lix physics. The three starter themes
are brick, earth and wood. Classic levels imported or selected from the personal
catalogue use the same visual adapter. Unmapped decorations and effects retain
their imported frames. Lix has no equivalent one-way mechanism, so the original
directional markers remain visible. The clean starter uses only mapped Lix
terrain, hatches and exits.

| Engine | Remaining work |
| --- | --- |
| Classic | All poses have a Lix mapping. Related animations approximate umbrella opening, Oh No and explosion. |
| Lemmings 2 | Common movement and work states have mappings. Other special actions use a neutral pose. Native attachments retain their imported anchors. |
| Lemmings 3 | Common movement and work states have mappings. Swimming, shimmying and trapped states use a neutral pose. |

Terrain art is not a replacement collision mask. Verify dimensions, anchors,
trigger regions, steel and terrain masks before applying it to an existing
level. Lix levels use a separate engine family and are not made compatible by
copying their graphics. No Lix levels enter this resource pack.

Run `zsh Scripts/run-lix-scene-artwork-tests.sh` to check the actual source
frames, transparency, animation, spawn and exit anchors, water, fire, traps,
terrain edits and steel. The suite also checks the three starter themes at
1× and 2×. It uses the offscreen, muted runner.

Run `zsh Scripts/run-lix-interface-artwork-tests.sh` for the authored button,
skill and checkbox frames and the source button palette. Run
`zsh Scripts/run-lix-interface-text-tests.sh` for exact font pixels, palette,
glyph rejection and complete proportional-text fitting. Full-window HUD
captures also cover normal and narrow layouts, Pause/Play, End Run/Undo and
the original-font and clean-font profiles. Playfield-only captures do not
establish HUD typography or button appearance.

Music files have verified playback formats and complete silent decode checks.
Listening, loop quality and in-game assignment remain unverified. No audio
test may become audible without a separate user request.

Before a store build, complete the
[content-distribution conditions](ModernReleasePlan.md#release-conditions),
including branding, launch assets, level rights, rendered states, accessibility
and each advertised platform's device checks. Current legacy packaging still
contains other source material. This resource pack does not certify that build
for App Store distribution.
