# Tamil pixel font experiment

This experiment measures the work needed to make a Tamil bitmap font that fits
the Lemmings artwork. It produces editable pixel masks, sprite atlases, metrics,
labelled glyph sheets and a standalone specimen page. The application loads an
exported candidate pixel font from `Localization.bundle/Fonts/TamilPixelFont.json`.
The specimen and source font files remain developer tools.

## Scope

The inventory contains 456 unique NFC entries across 21 groups:

- The 247 modern Tamil alphabet forms.
- All five Grantha additions and their vowel forms.
- All 13 kssa forms and the shrii ligature.
- Every assigned scalar in the Tamil and Tamil Supplement blocks.
- Every approved Tamil named sequence in Unicode 17.
- ASCII digits, punctuation and space.

These categories overlap. The inventory also records 76 canonical input aliases
and the common SA-based shrii spelling. The JSON retains the source names,
code points, group counts and Unicode source hashes.

This is a superset for visual review. It includes historic fractions and symbols
that the app is unlikely to need. It does not cover other Indic scripts or all
possible arbitrary mark sequences. A fluent Tamil reader has not reviewed it.

## Measured first result

The first experiment on 15 October 2026 took about 15 minutes of elapsed time,
including parallel inventory and artwork inspection. This covered the source
fonts, generator, six atlases, editable pixel rows, specimen page and targeted
checks. It measures an automated draft based on Noto outlines. It does not
measure the time to hand-draw or linguistically approve a new typeface.

All 1,368 glyph instances passed structural verification. The six atlas images
contain only the specified palette colours and binary transparency. Every
sprite fits within its atlas. Two letter/digit pairs share silhouettes in all
three sizes: எ/௭ and க/௧. The verifier records these six warnings for review.

Browser checks covered size and palette changes, group and diagnostic filters,
canonical input normalisation, both shrii spellings and visible unsupported
input. The browser reported no script errors. The first browser check found
that the alternate shrii spelling split into two sprites. The specimen now
maps that spelling to the documented shrii glyph.

## Build

Use macOS with Swift, Core Text, Python 3 and Pillow. The repository has no
existing Tamil font generator script, so this experiment has its own build entry.
It uses the bundled font files and needs no network access.

1. Select a Python interpreter that has Pillow.
2. Run the generator from the repository root:

   ```sh
   TAMIL_PIXEL_PYTHON=python3 zsh Tools/TamilPixelFont/build.sh
   ```

3. Open `Tools/TamilPixelFont/output/index.html` in a browser.
4. Review `output/overview.png` and the labelled glyph sheets.
5. Read `output/verification.json` for coverage errors and shape collisions.
6. Export the runtime font and its notices:

   ```sh
   python3 Tools/TamilPixelFont/export_runtime.py
   ```

The build stops if a required input is missing or a structural check fails.
Generated output, compiler caches and original commercial artwork references
are ignored by Git.

The exporter uses Python's standard library. To export an existing prototype
from another folder, pass `--prototype /absolute/path/to/output`. It writes
the compact runtime JSON and copies the OFL and Unicode notices into
`Sources/NxlvKit/Resources/Localization.bundle/Fonts/`.

## Method

`rasterise.swift` uses Core Text to shape each complete Unicode sequence. The
source typefaces are Noto Sans Tamil Bold, Noto Sans Tamil Supplement and the
Noto Sans Bold companion for ASCII. Each glyph record retains its source font
and glyph IDs, so an unexpected fallback cannot silently pass verification.

The script samples outlines at four times the final resolution. `build.py`
reduces the masks by pixel area and applies a fixed threshold of 112. The result
contains solid pixels with no smoothing. It then adds a one-pixel outline,
bevel and restrained texture using the original seven-colour ramp. The green
version uses the application's RGB-to-GBR channel rotation.

The small, large and detail designs use Tamil body heights of 14, 18 and 26
pixels. Widths vary by sequence. Marks retain their full height. The original
Macintosh font cells measure 12 × 18 and 16 × 20 pixels. The integrated renderer
keeps original Latin advances and measures Tamil sequences separately.

Isolated combining signs appear on a dotted circle for inspection. Their
records have `diagnosticOnly: true`. They must not become standalone sprites
inside normal words. The specimen composes words from complete inventory
sequences and accepts the documented normalisation aliases.

The source silhouettes come from Noto. The generated pixel finish borrows the
Lemmings palette and edge treatment. A type designer must still review the
letter shapes, stroke weight, counters and spacing at the smallest size.

## Validation boundary

The targeted verifier checks inventory consistency, source hashes, font
fallbacks, missing glyphs, blank masks, clipping and exact pixel-shape collisions.
It records collisions as review warnings because some Tamil letters, digits
and historic symbols can share a shape.

These checks establish that the specimen covers its inventory and can be
recreated. They do not establish fluent readability, typographic quality,
application layout, accessibility or complete Tamil localisation. They do not
establish a completed application regression run.

## Candidate app integration

Runtime export contains 399 complete Tamil forms in each of the three heights,
plus the common SA-based shrii alias. It excludes 43 ASCII support entries and
14 dotted-circle diagnostics from each prototype face. Original game Latin
glyphs and advances stay authoritative. Two palette indices pack into each
resource byte. The exported source hashes identify the prototype pixels.

`BitmapTamilGlyphs` normalises NFC and matches the longest complete sequence.
Kssa and shrii remain single layout units even across Swift `Character`
boundaries. Shared controls, the compact fallback and native Classic, Lemmings 2
and Lemmings 3 text use measured widths, bounds, wrapping and truncation.
Baseline alignment retains negative bearings and vowel/pulli overhang. Sequel
conversion uses each original font's shade indices. Compact L2 rows preserve the
full row within the existing band and truncate at whole sequence boundaries.

Runtime rendering reads packed pixels and uses bounded derived-frame caches.
It needs no Core Text, source TTF or system font. The existing localisation
bundle packaging carries the runtime font and notices to Mac, iOS and tvOS.

The shared translation catalogue serves eight translation locales and includes
eight plural keys. The seven existing packs remain AI drafts. The Tamil draft
pack is complete. A fluent Tamil reader must still review the
smallest glyphs, wording and spacing. Complete translated journeys, accessibility,
input targets and physical-device acceptance remain open. See
[localisation](../../Documentation/Localisation.md) for the current checkpoints
and focused application test commands.

Use **Settings > Gameplay > Language** to preview Tamil immediately.
Choose **Apply** to save the choice. Choose **Back** to undo the preview and
restore the previous language. **System default** follows the device language.

## Sources and licences

The source fonts and their notices are in `vendor/`. The font artwork and any
derived bitmap font remain under the SIL Open Font License 1.1. The modified
bitmap experiment uses its own name. Source URLs and SHA-256 hashes are in
`vendor/sources.json`.

- [Noto Tamil sources](https://github.com/notofonts/tamil).
- [Noto Latin source fonts](https://github.com/notofonts/noto-fonts).
- [Unicode 17 Tamil specification](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-12/).
- [Unicode named sequences](https://www.unicode.org/Public/17.0.0/ucd/NamedSequences.txt).

Unicode data is © 2025 Unicode, Inc. Its notice is reproduced in
`vendor/UNICODE-LICENSE.txt`. Original game glyph pixels used as a local visual
reference remain in the ignored `reference/` directory.
