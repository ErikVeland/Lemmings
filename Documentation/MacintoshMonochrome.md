# Macintosh 1-bit artwork

Settings → Graphics → Classic artwork → Artwork offers **Macintosh (1-bit)**
when the decoded monochrome banks are installed. The shared iOS and tvOS
artwork selector offers the same source.

The artwork comes from the supplied releases' separate `BW Graphics` files:

| Family | Source | Format |
| --- | --- | --- |
| Lemmings | Lemmings 1.5.2 disk | SHPD v1 |
| Oh No! More Lemmings | Supplied disk images | SHPD v2 |
| Xmas | Xmas Demo '92 | SHPD v1 |
| Holiday | Holiday Lemmings 1994 installer | SHPD v2 |

`Tools/MacArtwork/prepare.py` exports these banks under
`MacArtwork/monochrome/<family>`. Each frame retains its signed origin,
word-aligned width and separate transparency mask. The decoder reads alternating
16-bit mask and image words. A set mask bit is transparent. Otherwise, a set
image bit is black and a clear image bit is white. Special pictures use the
existing PICT decoder. The manifest records `monochrome: true`. Older colour
manifests without this field continue to load.

Classic uses the authored terrain, object animations and lemming poses at 2×
simulation resolution. Changing artwork preserves the current simulation,
assignments, terrain edits and rewind history. Construction pixels are white.
Changed or missing fan pieces retain the existing reconstruction geometry and
use ordered monochrome dithering. Original black and white pixels remain exact.
Xmas '91 and Holiday '93 use the same later seasonal artwork families as the
existing colour option. Their edition-specific graphics are not established.

Menu lettering and shared stone controls retain the shipped colour interface.
The selection, pointer and optional HD effects retain their selected settings.
The existing **Show skill backpacks** preference also applies to monochrome
sprites. Climbers use diagonal dithering, Floaters use horizontal stripes, and
lemmings with both skills use a checker pattern. All marker pixels remain black
or white. Preparation records torso anchors and foreground masks from each
matching colour frame, aligned by the authored frame origins. The shared Mac
and mobile renderer uses these guides to keep hair, faces and hands in front.
It mirrors the pack with the pose, including the reversed body under an umbrella.
The sprite cache, selection and speed trails use the decorated sprite. Death and
exit poses omit the marker. Disabling the preference restores the source pixels.
Older decoded banks without guides still load and need preparation again to
show monochrome backpacks.

Lemmings 2 and Lemmings 3 keep their separate native and reconstructed 2×
artwork options. No original 1-bit sequel banks have been identified in the
supplied data. NeoLemmix keeps its existing artwork options. This setting adds
the original Classic Mac banks, rather than a monochrome filter for those engines.

Mac bundles export the banks during normal data preparation. iOS and tvOS copy
the same prepared banks through `Tools/IOSBeta/artwork.py`. Prepare the banks
before building either mobile app:

```sh
python3 Tools/MacArtwork/prepare.py .build/mac-artwork/export
python3 Tools/MacArtwork/test_decoder.py
python3 Tools/UITestRunner/run.py swift test --filter 'MacMonochrome|MobileArtworkTests'
```

The focused checks cover mask polarity, padding, null slots, truncated frames,
binary pixels, all lemming poses, campaign object mappings, representative
terrain styles and special pictures, construction pixels, saved preferences,
live source changes, digging, rewind and checkpoints. Native checks capture the
Settings choice and playfield offscreen and verify the choice's mouse target.
They write captures to `.build/mac-monochrome-captures`.

Backpack checks cover all poses and both directions in the four artwork
families, distinct patterns, foreground preservation, binary pixels, the saved
toggle, cache isolation, mobile checkpoint restoration and unchanged input
targets. The native check also exports a pattern comparison as `backpacks.png`.

An original-machine comparison, mobile device rendering and a full sweep of
all animation poses in gameplay remain separate validation.
