# Optional soundtrack libraries

The default app bundles the 54 essential versions: released native modules and
the recording-only Professor Mariarti theme. The other 441 versions are divided
into 18 optional libraries. The catalogue remains complete so installed libraries
can join the same composition journeys without changing the level's tune.

Build verified libraries after running the timing and rhythm tools:

```sh
python3 Tools/MusicCatalogue/library.py packs --output .build/music-libraries/1.6
cp .build/music-libraries/1.6/libraries.json Resources/Music/libraries.json
zsh Scripts/run-music-library-tests.sh
```

The ZIPs contain playable files, relevant beat grids and rhythm loops. Apple
Lossless tracks become 192 kbps AAC, with the encoder and cache of
`Scripts/compact-bundled-music.sh`. A library file is then byte-identical to the
copy inside a full app. Timing and rhythm entries record the AAC hash as
`playbackSHA256`. WAV files, MP3 files, modules and rhythm loops stay unchanged.
Source-only archives and the `By Track` browsing links are excluded. Fixed ZIP
timestamps make repeat runs deterministic with the same encoder and inputs.
Every archive and member has a size and SHA-256 in the bundled index. Installation
checks these values, rejects unexpected paths and archive entries, and replaces
a library only after all files pass. Interrupted installs leave the existing
library intact. Files live under Application Support/Ultimate Lemmings/MusicLibraries.

The default URLs refer to the GitHub release asset tag `music-1.6`. **Those assets
must be published before public in-app downloads work.** The packaging command
only creates local artifacts. Use `--base-url` before building the app to choose
another HTTPS asset location. Keep published archives immutable: rebuilding a
ZIP under the same URL invalidates the hash stored in older apps. A new library
revision needs a new release tag and matching app index.

Main and full app builds use the same code and download manager. A full build
re-encodes its Apple Lossless tracks the same way and records their playback hashes:

```sh
MUSIC_BUNDLE=main zsh Scripts/build-local-app.sh
MUSIC_BUNDLE=full LEMMINGS_BUILD_DIR="$PWD/.build/full-music" zsh Scripts/build-local-app.sh
```

`Scripts/package-beta.sh` accepts the same setting and names the full archive
with `-full-music`. `BETA_SLIM=1` is an alias for the main bundle. The legacy strip
script now rebuilds the main set so it retains the essential recording and its
metadata. Signing, notarisation, proof/hint checks and release publication remain
separate release steps.

Sparkle replaces the whole app, so every update must carry the full soundtrack.
`Scripts/build-and-notarise.sh` builds the update, Monterey and Game Center targets
with `MUSIC_BUNDLE=full`. Only the fresh-install `-slim.zip` download uses `main`.
