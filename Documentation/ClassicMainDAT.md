# Classic `MAIN.DAT` gameplay assets

`ClassicMainDATAssets` decodes gameplay graphics from a `MAIN.DAT` file that
the player supplies. The project does not copy or include these commercial
assets.

## Sources

The byte layout follows ccexplore and Mindless's `MAIN.DAT` format research:

- <https://www.camanis.net/lemmings/files/docs/lemmings_main_dat_file_format.txt>

The implementation was cross-checked against these source implementations:

- Thomas Zeugner's MIT-licensed sprite and mask readers:
  <https://github.com/tomsoftware/lemmings.ts/tree/master/src/game/resources>
- VorticonCmdr's independent DAT decompressor and planar-image reader:
  <https://github.com/VorticonCmdr/lemmings/tree/main/src>

The decoder uses bounds checks for all section, frame, plane, and palette
accesses. Color index 0 is transparent in the gameplay sprites. The decoded
indexed pixels remain available because the current ground style supplies
palette indices 7 through 15.

## Supported content

- All section 0 lemming graphics: 30 directional sequences and 337 frames.
- All section 1 destruction masks: four bash frames per direction, two mine
  frames per direction, and one explosion mask.
- All ten section 1 explosion-countdown glyphs.
- Indexed pixels, per-pixel opacity, draw offsets, and dynamic RGBA conversion.
- A VGA in-level palette helper. It combines the seven fixed gameplay colors
  with one selected terrain palette and expands 6-bit DAC values consistently
  with the classic terrain renderer.

The frying sequence uses palette indices through 13. A fixed seven-color
sprite palette is therefore not sufficient for exact rendering.

## Fixture verification

`Scripts/verify-main-dat.sh` validates the local original DOS fixture against
an independent JavaScript decoder. It checks the archive and section SHA-256
values, every indexed sprite pixel, every RGBA pixel for ground style 0, every
expanded mask bit, and malformed section rejection.

The audited local archive has SHA-256 value
`2aec688c334e60322998811a8b6f9d5c13f8090b46ca6c2a6cb1c8db3b733545`.
Its seven unpacked section sizes are 21,104, 388, 8,384, 61,968, 36,080, 758,
and 8,224 bytes.

## Not decoded

- Section 2 high-performance skill panel, numbers, and font.
- Section 3 main-menu graphics, which hold the title logo. Decoding was
  attempted and is not solved. Whole-image four-plane decoding at 632 pixels
  wide produces recognisable lemming figures and the trademark mark, so the
  width is right and the section is not encrypted. Row-interleaved planes give
  noise. A width sweep scored 632 highest at 0.29 row-to-row coherence, far
  below the 0.7 or better that plain artwork gives, so the pixels use an
  encoding this project has not identified. Until that is solved the title
  screen has no logo when the original artwork is selected.
- Section 4 menu animations, signs, scroller graphics, and purple font.
- Section 5 unknown data.
- Section 6 standard skill panel and green font.
- Native `CGAMAIN.DAT` graphics.
- Explosion-shower particles that the DOS game draws separately.

The original DOS `MAIN.DAT` fixture is fully verified. Other official packs
use the same general layout, but they need separate golden fixtures before the
project can claim byte-for-byte coverage for them.
