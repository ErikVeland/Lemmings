# Macintosh-style sequel artwork

## Reference study, before sequel conversion

The source study uses the supplied DOS and Macintosh releases of Lemmings,
Oh No! More Lemmings, Xmas 1992 and Holiday 1994. `reference.swift` exports
2,703 matched terrain, object and sprite records. No image is interpolated.
Object sequences with different frame counts are excluded from automatic
correspondence. Equal frame counts do not prove equivalent animation phases.

Macintosh frames are often cropped and have signed origins. Comparing raw
file dimensions is therefore misleading. Terrain and objects are aligned by
their authored origins on a doubled DOS canvas. Sprite actor origins differ
between ports. Their measurement uses integer translation to maximise mask
overlap. This alignment is for analysis only, never sequel registration.

The first pass measures all matched terrain and object frames and the first
frame of each sprite sequence. A split block is an occupied 2×2 area with
more than one RGBA value, including transparency.

| Reference | Records measured | Occupied blocks split at 2× |
| --- | ---: | ---: |
| Lemmings terrain | 272 | 57.8% |
| Lemmings ordinary objects | 201 | 45.2% |
| Lemmings traps | 159 | 64.2% |
| Lemmings sprites | 30 | 45.0% |
| Oh No! terrain | 225 | 21.7% |
| Xmas / Holiday snow terrain, each | 37 | 7.7% |

These are descriptive measurements, not target edit quotas. Xmas and Holiday
share many assets and are not independent evidence. Liquid height and phase
differences make their raw pixel error unsuitable as a quality score.

Visual inspection of the reference sheet shows:

- Dirt adds short, clustered highlight and shadow marks inside existing
  material regions. Large colour masses and the original light direction remain.
- Brick mortar stays straight and regularly spaced. Flat fills retain blocks.
- Pebbles and snow refine stepped internal contours. Snow keeps much more of
  its enlarged source than the original dirt set does.
- Lemmings retain economical colour regions. Hair tips, faces and cuffs receive
  small integer-pixel changes. They are not given modern dark outlines.
- Metal exits retain separate dark joints and bright rivets. The hatch adds
  small marks and changes the border independently of its landscape insert.
- Water is materially redrawn, including its height. Its bright marks remain
  discrete pixels. A direct geometric transplant would violate this task's masks.

## Constraints on inference

The reference is hand-authored and is not the output of a universal scaler.
An automatic reconstruction cannot recover the artists' intent uniquely.
Category-specific neighbourhood rules can transfer observed colour boundaries,
but ambiguous shapes must retain the source block. They must not receive random
texture. Repeated animations must use the same rule without a time or frame seed.

For the sequels, source transparency takes precedence over reference silhouette
changes. Every transparent source pixel remains four transparent pixels, except
for a liquid frame tail below an existing liquid column. Every opaque source
pixel remains four opaque pixels. Reconstruction changes colour within those
masks. The pipeline must not copy the Mac water height, cropped origins, altered
proportions or frame timing into a sequel.

All generated images and comparison sheets remain under `.build/`, alongside
the supplied commercial data. The repository holds the generation code and
measured rule evidence, not copies of the game artwork.

## Implemented reconstruction

`SequelMacArtwork` generates separate RGBA frames. Source palettes, sprite
commands, level records, collision masks and simulation code remain unchanged.
The generated rule tables are compiled into the app. Playing the sequels needs
neither Python nor an installed Macintosh release.

Five categories cover characters, organic terrain, architecture, mechanical
objects and liquids. Exact 3×3 tables encode colour equality, light direction
and broad hue. A second table recognises two-colour boundaries within complex
shading. Outputs select discrete source colours. Uncertain patterns retain
their source pixels.

The first object rules overfit individual animations. Requiring support from
two independent object sequences reduced that error. The checked-in development
measurements include the nearest-neighbour baseline. They measure quantised,
registered pixels and were used during tuning. They are not an untouched test
set or a claim of Macintosh pixel equivalence.

Four curated treatments supplement the tables:

1. Characters separate the warm face from pale sleeves and shoes. The exact
   Macintosh face and eye colours are `#FFAA22` and `#660011`. Green hair and
   nearby pale pixels identify the head. The three-colour L2 walker uses its
   defined palette roles for clothing, hair and skin. This also handles tan
   skin and red, blue or dark hair. Its cuffs and shoes become pale while
   the hair keeps its tribe colour. A centred face receives no guessed facing
   direction. L3 creatures use the general object rules.
2. Organic terrain uses measured small highlight and shadow clusters. Gradient
   tables select marks for recognised neighbourhoods. A tone stencil records
   mark spacing from the opaque dirt patch at source coordinate `(13, 12)`.
   It has twelve light marks and twelve shadow marks per 8×8 visual pixels.
   Only textured, saturated regions use this fallback. Flat fills, architectural
   surfaces and transparent pixels do not receive it. Marks use neighbouring
   palette tones. They do not copy the source terrain shape or invent colours.
3. Liquids fill the transparent tail below existing liquid columns, then narrow
   an existing bright surface glint to one visual pixel. Empty columns remain
   transparent. This removes black gaps without changing the liquid footprint
   at the sides or its collision tags. Isolated glints become one pixel;
   connected crests retain a horizontal pair.
4. Small neutral metal highlights receive faceted corners, as seen in the Mac
   exit's studs and dark joints. Only connected highlight patches no larger
   than 3×3 source pixels qualify. Corner marks use an existing darker neutral
   neighbour. Large panels, coloured surfaces and opacity edges are excluded.
   This is a curated material inference, not a learned pixel equivalence.

Organic marks use a fixed phase in native terrain coordinates. Animation clocks
and random numbers do not affect reconstruction. Each terrain layer is converted
after native tiles are assembled, so joins see their real neighbours. The full
style palette stays fixed during digging and building. Removing a colour from
the map cannot change distant shading.

Optional `PixelEdit` records support asset-specific corrections. They cannot
change dimensions, opacity or registration. Partial alpha is rejected. No
continuous-image filter is used.

L2 front-end pictures, panel icons, bitmap text and cursors receive separate 2×
backing images. L3's original panel and bitmap font now receive the same artwork treatment. The classic DOS
decoder exposes its status panel but not the full menu font/artwork, so there
is no complete matched DOS/Mac UI corpus here. UI inference preserves the
original layout and uses architectural colour-boundary rules. A presentation-only
contour pass refines matching diagonal colour edges in illustrations and lettering
at 2× resolution. It can refine binary silhouettes in front-end assets, which
have no collision masks. It never runs on gameplay terrain or actors. This is
discrete reconstruction, not hand-drawn Macintosh sequel artwork.

## Using the artwork

The option is on by default, including upgrades from the earlier opt-in release.
It covers gameplay, menus, intro screens and level briefings. Choose **Options → Graphics → Lemmings 2 + 3 →
Macintosh-style 2× artwork**. L2 also exposes it on its Preferences screen.
L3 has an artwork choice in its in-game menu. All controls use the same
saved preference. Switching during play preserves the simulation, camera,
skill selection and progress.

`SequelArtworkRenderer` retains original logical image sizes while supplying
doubled backing pixels. Frame offsets and draw coordinates therefore stay
unchanged. Its 64 MiB image cache keys include pixels, palette, opacity,
category, mode and rule revision. Cached images cannot replace a new palette
or rule set. The renderer never writes source data.

## Reproduction and verification

Run the complete conversion and real-canvas tests:

```sh
zsh Scripts/run-sequel-mac-artwork-tests.sh
```

The supplied data produces 59,542 frame variants, including all twelve L2
tribe palettes, VLEMMS, extracted walkers, regular and special object banks,
internal effects, front-end palette variants, panel icons and bitmap text.
L3 coverage includes both object banks in all environments and every installed
tribe/creature IND/CMP bank. Point primitives retain their integer drawing and
original timing.

The audit renders terrain for all 120 L2 campaign levels, four practice maps
and 90 L3 levels. It checks exact dimensions, signed origins, binary alpha,
opaque black, transparent RGB, immutable input and deterministic output. A
terrain-edit check compares untouched pixels outside the changed neighbourhood.
Paired simulation runs check that rendering does not affect terrain, ticks or
outcomes. Existing sequel runtime tests remain separate physics checks.

The app harness captures the actual canvases at tick 110 in all twelve L2 tribes and
all three L3 environments. It captures PC artwork, the reconstruction, then PC
artwork again. The first and last PNGs must match exactly. This checks the mode
switch, camera, registration and scene state through the live views.
All 192 L2 walker variants must contain the Macintosh face, eye and pale cuffs,
and retain their tribe hair colour. A separate check clicks the actual Settings
checkbox while the Beach player is attached to a shared window. It verifies
the artwork change and restoration without changing gameplay or camera state.

Rebuild the reference analysis and A–F sheets with Python, Pillow and NumPy:

```sh
SEQUEL_ART_PYTHON=/path/to/python3 zsh Scripts/study-sequel-mac-artwork.sh
```

`MAC_ARTWORK_ROOT` overrides the decoded Mac artwork folder. The existing
importer can otherwise extract the supplied releases. The study script emits
candidate tables and compares them with the committed rules. It never silently
replaces production rules.

Outputs are under `.build/sequel-mac-artwork/`:

- `references/` and `measurements.json`: source evidence and measurements.
- `proof-v2/`: original and exact 2× proof assets, plus first-generation DOS/Mac
  level renders. The name records the expanded proof stage, not the rule revision.
- `comparisons/`: A–F sheets, registered animation strips and level comparisons.
- `levels/`: the actual app canvases in both modes.
- `complete/manifest.json`: full coverage, source/output hashes and signed origins.
- `complete/*.rgba`: deduplicated generated frames, keyed by output SHA-256.

L2 object proofs assemble all native components. Trap proofs also include their
terrain body where only eyes or other small moving parts belong to the object
animation. These context crops are labelled on the sheets.

Visual hashes in `Tests/SequelMacArtworkTests/goldens.json` cover materials,
characters, skills, objects, creatures and UI. After inspecting a deliberate
artwork change, `--record-goldens` records a new baseline. Do not use it to hide
an unexplained regression.

## Visual assessment

The proof was refined after native-size and integer-zoom inspection. The first
version retained too much PC texture and was rejected. The final organic
treatment separates fine pigment marks from larger source colour masses.
Characters use the Macintosh face/cuff distinction. Architectural edges retain
their original structure. The same treatments appear in actual L2 and L3 levels.

A broader corner lookup was also evaluated and rejected: on the development
objects it added edits without reducing pixel error. The final mechanical
refinement therefore targets compact metal highlights, while liquid refinement
targets existing glints. Neither treatment adds general surface noise.

This remains an inferred Macintosh-style asset set. It cannot recover the
missing decisions of an official sequel port. The original Mac artists also
redrew proportions, silhouettes and liquids, which this upgrade preserves from
the PC games. The A–F sheets expose those differences rather than treating
dimensions or test counts as proof of visual authenticity.

## L3 native control panel

L3 now uses the bundled `PAN004`, `PAN010` and `PAN005` panel artwork for
Classic, Shadow and Egyptian tribes. The normal and pressed panels decode the
original four VGA planes into a 320×40 image. The small `FONT.DEL` glyphs use
`FONT.DIN` lengths and bottom-up rows. Artwork preferences apply to the panel
as well as the playfield.

The five action icons, fast-forward and pause control the existing runtime.
Double-clicking the last icon opens the existing end-run confirmation. The
clock cell shows minutes and seconds. Hovering over a lemming with a tool shows
its icon and quantity in the Use Tool cell. Bricks and spades open a contextual
eight-direction picker; simulation waits until the direction is chosen or cancelled.

The top counter strip, 320×160 playfield and bottom panel occupy separate
rectangles. All world rendering, including overhead counters, is clipped to
the playfield. The direction picker is also bounded within it. Panel clicks
cannot assign actions to lemmings underneath the panel. L2's system-font
countdown is now a fallback only when its original COUNTDOWN sprite bank is absent.

Menu or Escape opens the bitmap game menu for resume, retry, tribe and level
selection, artwork and return to the library. Mouse-edge scrolling, wheel
scrolling and arrow keys move the camera. The menu retains the experimental
gameplay notice; this presentation change does not change L3 physics or
campaign-credit rules. Single-step remains a keyboard-only developer shortcut.

Validation covers all three tribe panels, original/2× artwork restoration,
nine panel hit regions, pause and fast-forward callbacks, double-click end-run,
menu pause, direction-picker isolation from panel pixels, and existing sequel
result/progression checks.
