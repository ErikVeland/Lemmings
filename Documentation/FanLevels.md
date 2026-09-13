# Fan levels

The app includes the packs in `Content/LevelPacks`. Fan Levels opens this
collection directly. No folder selection or internet connection is required.
The packaging step copies the ZIP archives and a level-count index into the
signed app bundle. The index is generated with the same decoder used for play.
Configuration INI files are excluded. Binary levels with an INI extension are
recognised by their contents.

At each launch, a background task checks the newest releases in the
[Lemmings Level Database](https://lldb.camanis.net/levelpack/list). It skips
installed pack IDs and follows listing pages until it reaches a page of known
packs. Requests are sequential and spaced by 1.5 seconds. This is an additions
check, not an automatic replacement of existing packs or saved solutions.

New archives are checked for size and ZIP structure, then inspected for readable
LVL, INI or classic DAT levels. Only a pack with readable levels enters the
library. It is written to a temporary file and moved into place after validation.
Executables in an archive are never run, and archive paths are never extracted
onto the filesystem. Unsupported formats and failed downloads do not appear as
empty packs. The next launch can retry them.

Downloads live in
`~/Library/Application Support/Ultimate Lemmings/Fan Levels`.
They supplement the embedded collection and remain available offline. A failed
check leaves all installed packs and progress intact. Status appears in the fan
pack browser, without a dialog or separate window. Background additions preserve
the selected pack and do not change a running game.

File → Add Fan Level Folder remains available for an optional personal collection.
It adds to the built-in and downloaded collections. A missing personal folder
cannot hide the embedded packs. Duplicate catalogue IDs appear once.

The updater covers compatible releases in this database. It does not search forum
attachments or install engines and graphics dependencies for unsupported formats.

## Checks

`Scripts/run-fan-library-tests.sh` exercises first-run discovery, duplicate IDs,
download validation, pagination, repeat launches, offline operation and malformed
responses. Pass `--live` to also check the current public catalogue.

`Scripts/build-local-app.sh` runs `Scripts/index-fan-levels.sh` before packaging,
so the first launch has an accurate total without scanning every pack.

## Reviewed pruning

The working source after beta 28 contains 6,020 fan levels in 535 packs. The user
authorised removal of 23 empty or malformed records. No complete pack was removed.
`Tools/FanLevelCatalog/prune.py` reproduces the reviewed deletions from the original
archive hashes before indexing. Packaging checks the resulting archive hashes.

Pruned DAT archives contain `classic-section-slots.json`, mapping physical records
to their original slot numbers. Retained compressed records stay byte-for-byte
unchanged. Saved attempts keep their level identity, and restored queues omit
deleted entries. The [pruning manifest](FanLevelPruning.json) records every removal.
