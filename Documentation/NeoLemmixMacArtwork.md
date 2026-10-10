# Macintosh artwork for NeoLemmix

Settings → Graphics → Artwork → Macintosh also applies to NeoLemmix levels.
It uses native 2× Macintosh pixels where the source graphic matches. Other
graphics receive a separate 2× recreation based on their authored colours and
shapes. Changing artwork during play preserves the simulation and rewind
history. Other artwork settings use the level's NeoLemmix graphics.

The substitution covers the original Dirt, Fire, Marble, Pillar and Crystal
styles, and the Oh No Brick, Rock, Snow and Bubble styles. Each source graphic
must match the original decoded DOS pixels before the corresponding Mac graphic
can be used. Matching accounts for transparent border cropping, the original
VGA palette expansion and NeoLemmix's dark-yellow flame colour. Combined exit
and flame graphics are compared as a single animation. Each animation frame
retains its NeoLemmix position in the sequence.

Missing Mac pieces, changed graphics, custom styles and unmatched gadgets use
measured Macintosh colour-boundary rules. Organic terrain and objects,
architecture, mechanical objects and liquids receive different treatments. The rules
work within the source's logical opacity and keep its colours and placement.
Each recreated 2× cell keeps the source cell's alpha, including partial alpha.
The renderer recreates object animation frames separately, so adjacent frames
cannot affect one another's detail.
Uncertain patterns retain a clean 2× source block. The same rules apply to
player-supplied styles when the player adds them. Matching native Mac art never
guesses from a piece name or silhouette alone. A level can mix native Mac and
recreated art. Source artwork keeps its logical level size; Macintosh mode adds
a separate 2× display plane.

The renderer carries 2× display pixels separately through placement, cropping,
rotation, flipping, terrain groups and resizing. It also retains detailed
backgrounds, foregrounds and each object animation frame. The original
NeoLemmix image still determines solidity, steel, one-way masks and trigger
geometry. Digging, construction and rewind update the display from the live
simulation. If a native Mac silhouette leaves a whole solid logical cell
transparent, the original pixel fills that cell so walkable terrain stays
visible.

Common lemming actions use native Mac frames when their animation lengths
correspond. NeoLemmix-only actions, custom sprite themes and trait colours use
recreated 2× frames with small face, hair and clothing details. The source
silhouette, foot anchor, direction and frame timing remain unchanged. Skill
icons in the panel and beside the cursor use the same artwork selection.
Stone sockets and control glyphs also use 2× display pixels in Macintosh mode.

## Validation

`zsh Scripts/run-neolemmix-mac-artwork-tests.sh --all-redux` compares the bundled
Redux levels' original pixels, collision masks and simulation configurations.
It also checks all eight terrain transform combinations, native-resolution
pixels, digging and restored simulation frames. The script expects a prepared
local app at `.build/local/Ultimate Lemmings.app`, or `LEMMINGS_TEST_APP`.

`zsh Scripts/run-neolemmix-recreated-artwork-tests.sh --all-bundled` checks
recreated terrain, objects, backgrounds, partial alpha and repeated renders.
It tests a terrain and object fixture for each of the 26 bundled styles. It
compares the bundled levels' source pixels, masks and simulation settings, and
reports levels whose styles the player must supply. It saves comparison images
under `.build/neolemmix-recreated-artwork/previews`.

`zsh Scripts/run-playfield-draw-tests.sh` captures the actual views offscreen,
with audio muted. It checks Mac and original artwork switching, native detail,
extra-skill and trait fallbacks, cursor-icon cache refresh and Classic controls.
The previews are in `.build/neolemmix-panel-regression`.

These changes affect NeoLemmix presentation. Classic and the sequels use their
own artwork paths. The checks run offscreen and muted.
