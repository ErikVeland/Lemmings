# Macintosh artwork for NeoLemmix

Settings → Graphics → Artwork → Macintosh also applies to NeoLemmix levels.
It replaces verified original-style pieces with native 2× Macintosh pixels.
Changing artwork during play preserves the current simulation and rewind history.
Other artwork settings use the level's NeoLemmix graphics.

The substitution covers the original Dirt, Fire, Marble, Pillar and Crystal
styles, and the Oh No Brick, Rock, Snow and Bubble styles. Each source graphic
must match the original decoded DOS pixels before the corresponding Mac graphic
can be used. Matching accounts for transparent border cropping, the original
VGA palette expansion and NeoLemmix's dark-yellow flame colour. Combined exit
and flame graphics are compared as a single animation. Each animation frame
retains its NeoLemmix position in the sequence.

Missing Mac pieces, changed source graphics, custom styles, extended pieces and
unmatched gadgets retain their NeoLemmix graphics. Matching does not guess from
a piece name or silhouette alone. A level can contain both kinds of artwork.

The renderer carries Mac display pixels separately through placement, cropping,
rotation, flipping, terrain groups and resizing. The original NeoLemmix image
still determines solidity, steel, one-way masks and trigger geometry. Digging,
construction and rewind update the display from the live simulation. If a Mac
silhouette leaves a whole solid logical cell transparent, the original pixel
fills that cell so walkable terrain stays visible.

Common lemming actions use Mac frames when their animation lengths correspond.
The placement uses the original sprite origins. NeoLemmix-only actions, custom
sprite themes and trait colours retain their authored NeoLemmix sprites. Skill
icons in the panel and beside the cursor use the same artwork selection.

## Validation

`zsh Scripts/run-neolemmix-mac-artwork-tests.sh --all-redux` compares the bundled
Redux levels' original pixels, collision masks and simulation configurations.
It also checks all eight terrain transform combinations, native-resolution
pixels, digging and restored simulation frames. The script expects a prepared
local app at `.build/local/Ultimate Lemmings.app`, or `LEMMINGS_TEST_APP`.

`zsh Scripts/run-playfield-draw-tests.sh` captures the actual views offscreen,
with audio muted. It checks Mac and original artwork switching, native detail,
extra-skill and trait fallbacks, cursor-icon cache refresh and Classic controls.
The previews are in `.build/neolemmix-panel-regression`.

These changes affect NeoLemmix presentation. Classic keeps its existing Mac
renderer. Lemmings 2 and 3 keep their separate artwork paths. No foreground or
audible tests are required.
