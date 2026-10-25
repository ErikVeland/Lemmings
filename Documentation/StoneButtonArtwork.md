# Stone button artwork

Shared colour stone sockets use the original Macintosh **Lemmings** background
rock, `Charset2` frame 95 in `MacArtwork/lemmings`. This is the colour counterpart
of the background rock already used by the original monochrome buttons.
Its fine grain has no boulders, brick outlines or slab edges.

Every source pixel draws at one logical pixel. Button width, height and bevel
do not change the texture scale. Larger buttons continue the authored 320 × 108
background tile at the same scale. All sizes expose the same texture from the
top-left of the well, so resizing cannot zoom or replace the visible grain.

The cached bitmap keeps the source colours and grain at 35% opacity over the
existing socket colours. This keeps the surface quiet behind lettering and
preserves caller opacity for disabled controls. The renderer does not generate
grain, reconstruct terrain, enlarge pixels or add texture resource files.
Existing packaging already includes this frame on all platforms and in
standalone sequels.

Selected controls retain the green face, reversed bevel and moss underline.
Focus outlines, action labels, accessibility and input bounds keep their
existing behaviour. The original
one-bit Macintosh presentation retains its own rock and monochrome states.
Passive information panels retain their flat backgrounds.

## Gameplay controls

`GamePlayButtonArt` gives skills, rate, pause, nuke, speed and transport controls
distinct faces. General UI buttons keep the quiet surface described above.
Mac, iPhone, iPad and TV use the same gameplay face identities.

The original Macintosh `Charset2` frame 107 contains twelve 32 × 48 panel cells,
starting at x = 32. Their six warm rock colours and exposed rock pixels are
preserved. Counters, symbols and sprites are baked into that bitmap, so it does
not contain complete, unobstructed rock faces. The recovered 28 × 44 interiors
exclude the counter sockets and all foreground colours.

Covered regions and larger control surfaces use patch synthesis from the
opaque rock interiors of Macintosh `Grounds2` frames 16, 17 and 18. Source
terrain tones map to the original panel's rock palette. Lava, transparent
outlines and shaped terrain edges do not enter the patch library. Overlapping
20 × 20 source patches match along their boundaries. Stable control identities
select different patch sequences. Adjacent patches cannot reuse the same source
patch. The resulting faces do not tile or repeat a shared button image.

Source grain stays at one pixel per logical pixel. Synthesis extends on resize
while preserving the existing crop. The original exposed panel pixels replace
their corresponding synthesized pixels. A light shade supports bitmap lettering.
Selection keeps its existing bevel, green cue and underline without replacing
the face. The bounded cache stores rendered faces in memory; no extra texture
asset or resource bank is exported.

Original game sprites retain their own artwork. Pause and end-run symbols omit
their old Amiga rock background over the new faces. Pause uses the same pale
ink as Play for contrast. Native Lemmings 2 and 3 panels retain their authored
faces; their added controls and shared compact HUDs use the new gameplay faces.
The existing monochrome presentation retains its original artwork and states.

## Verification

Run `Scripts/run-stone-button-art-tests.sh`. It renders offscreen with muted
audio through the standard UI test runner. The audit compares native and shared
socket pixels at two bevel sizes, checks original rock, monochrome, clipping
and the former repeated-stamp regression, verifies identical grain pixels across
four width/height changes and bounds texture contrast, and captures menu and HUD
states with their input rectangles. Captures go to `.build/stone-button-art/renders`.
`fixed-rock-grain.png` compares 44-, 128-, 320- and 656-point buttons at the
same height.

Gameplay checks verify all twelve recovered faces against the original Macintosh
panel, eighteen distinct face images, fixed grain on resize, the original rock
palette, absence of periodic tiles and native/shared parity in selected and
monochrome states. `gameplay-mac-rock.png` shows the separate faces and the actual
Macintosh skill sprites. Classic HUD fixtures also use these sprites.

The HUD fixtures cover Classic, Lemmings 2 and Lemmings 3 with shared snapshot
data. They verify artwork and target geometry, rather than native sequel panel
assets, engine progression or physical touch and remote event delivery.
Compile both frontends with `Scripts/check-apple-ui-sdk.sh ios` and
`Scripts/check-apple-ui-sdk.sh tvos`. These checks do not launch a Simulator.

On this host, extracting native `NSImage` symbol pixels aborts during macOS
application registration. The headless audit therefore checks their shared
source colours and the native socket adapter's bitmap output. Native `NSImage`
symbol drawing remains an in-app check.
