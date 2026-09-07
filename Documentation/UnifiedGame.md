# Unified game library

The macOS app uses one window for the classic, Lemmings 2 and Lemmings 3
engines. The game library lists all eight releases in canon order. Click a
release or select it with the arrow keys and Enter. Command-Shift-L returns
to the library. File → Game and File → Level provide direct navigation.

Full Quest resumes at the first unfinished installed release. Classic
campaigns resume at their first unpassed level, including gaps left by direct
level selection. A completed release continues into the next engine. Single
game mode returns to the library. Finishing only the final level does not
complete an entire campaign.

Each engine retains its own campaign rules and save format. On first use,
the combined app imports bundled-game saves from the standalone L2/L3 apps
without overwriting its existing saves. The library
reads validated progress from those stores. Native sequel progress does not
award verified classic achievements. Only the active engine advances its
simulation. Switching engines stops the previous engine's audio.

## Classic campaigns

- Lemmings: 120 levels in the original four ratings.
- Oh No! More Lemmings: 100 levels in Tame, Crazy, Wild, Wicked and Havoc.
- Xmas 1991 and 1992: four levels each, identified by their ordered titles.
- Holiday 1993: 32 levels in Flurry and Blizzard.
- Holiday 1994: 32 new levels in Frost and Hail. The repeated 1993 levels
  appear once in the library, under their original release.

Oh No!'s physical archives are not its retail level order. The campaign
references follow the [LemmingsJS configuration](https://github.com/oklemenz/LemmingsJS/blob/master/config.json).
The tests verify all 100 references are unique and check the first level in
each rating. Saves from the old “All” rating migrate by physical record to
the corresponding retail rating and level. Xmas saves migrate to “Xmas”.

The supplied Macintosh Holiday 1994 installer is a StuffIt archive. The build
extracts its Levels resource fork with `unar`, then embeds it as an ordinary
file. No Macintosh executable runs. Native `LEVL` records 0–31 contain 1994;
records 32–63 contain 1993. Both use the existing classic level parser and
bundled Holiday module soundtrack. Macintosh artwork is now the default.
The DOS ground data remains the source of simulation masks and triggers.

Build dependencies: `unar`, Python 3, and ImageMagick (`magick`). The finished
app needs none of these tools or the source checkout.

## Verification and limits

Run `zsh Scripts/run-unified-game-tests.sh` after building the app. It checks
all eight navigation routes, incomplete sequel handling, skipped levels,
save migration, campaign counts and all 292 classic level renders, entrances,
exits and releases. These are load-and-run checks, not complete solution
replays for every level.

Lemmings 2 is a native beta with all twelve tribes, all 51 skills, native interactive
objects and four original practice maps. All 120 levels pass load-and-run
checks; full solution coverage is still incomplete. Lemmings 3 retains its native preview status.
The shared library does not remove either engine's existing limitations.

## Display and navigation

The app opens full screen. The flat display fits the playfield and toolbar
at the same integer scale when the window changes size. Levels start at the
center of their authored 320-pixel starting view; resizing preserves that
center. The library loads a terrain backdrop before the first level starts.

Macintosh artwork is the default for the six classic releases. Terrain and
objects retain their native 2× resolution. Lemmings and toolbar figures use
Mac animation frames, including the festive Xmas sprites. The library uses
the original Mac logo and bitmap lettering. Skill labels and the minimap
remain part of the shared interface.

`Tools/MacArtwork/prepare.py` reads the supplied HFS disks and resource forks,
decodes Presage LZSS and SHPD v1/v2, and exports portable RGBA banks with
origins, palettes, and object sequences. ImageMagick decodes the four special
level PICT images. The format reference is
[resource_dasm](https://github.com/fuzziqersoftware/resource_dasm/tree/fc32e18a5a7feadb507efabdc534e4ec9db6ae64/src/SpriteDecoders).
No artwork is downloaded during the build.

Lemmings uses the Mac 1.5.2 disk; Oh No uses its two Mac disks from the supplied
collection. Both Xmas releases use the bundled Mac Xmas '92 artwork. Xmas '91
also needs the retained brick bank's object definitions from the Holiday
installer. Holiday '93 and '94 use the installer graphics. Original fire
terrain piece 44 is empty in the Mac bank, so only that piece falls back to
DOS artwork. Lemmings 2 and 3 keep their existing assets.

Artwork changes do not change collision masks, skill rules, progression, or
replays. Digging and construction update the high-resolution picture from
the simulation mask; rewinding restores the matching picture. This is a Mac
artwork presentation of the existing simulation, not a recreation of Mac
physics. Settings → Graphics → Artwork can select DOS graphics again.

`zsh Scripts/run-mac-artwork-tests.sh` checks all 292 classic scenes, their
object sequences, every lemming pose in both directions, digging, and rewind.
Build the app first so the Holiday campaign fixtures are present. The visual
harness accepts `--mac-art .build/mac-artwork/export/lemmings` (or `ohno`,
`xmas`, `holiday`) for original-pixel screenshots.

### Artwork choices

Macintosh artwork is the default for the classic campaigns. Options → Graphics →
Artwork also offers Amiga and DOS (VGA). The choice is saved and takes effect in
an active classic level or its menu backdrop without restarting the simulation.
Lemmings 2 and 3 retain their own artwork pipelines.

The Mac and Amiga skill selectors use raised stone bevels, dark recessed wells,
and a pressed green selection state. The frames are drawn on the sprite pixel
grid. The DOS option retains its source toolbar.

`Tools/AmigaArtwork/prepare.py` exports the original Amiga three-plane terrain,
four-plane objects with masks, OCS palettes, and lemming animations into the same
RGBA bank contract as the Mac artwork. Each Amiga pixel becomes a 2×2 block;
this keeps the existing scene and sprite drawing paths and does not invent extra
image detail. All 292 classic scenes and their object mappings are covered.
Special Lemmings levels come from the Amiga ILBM files. Classic lemming animation
shapes come from the 1991 Amiga Code file; the Holiday and Xmas choices use the
Holiday palette and retained brick/snow artwork. The skill frame is shared UI,
not a claim to reproduce the original Amiga toolbar or front end.

To recreate the ignored Amiga source extraction, build the CAPS/SPS 5.1 decoder
locally, then run:

```sh
python3 Tools/AmigaArtwork/extract-disks.py /absolute/path/to/libcapsimage.so.5.1
```

The importer reads the supplied original IPFs, validates MFM sector checksums,
extracts the custom Psygnosis directory or Amiga OFS files, and validates the
ByteKiller checksums. It records source SHA-256 hashes in
`Sources/Ports/amiga_extracted/sources.json`. Normal app builds read these local
extracted files, use only Python's standard library, and perform no downloads.
The CAPS library is an import-time tool and is not included in the app.

Validation: `python3 Tools/AmigaArtwork/test_decoder.py`,
`Scripts/run-amiga-artwork-tests.sh`, and the classic settings tests.
