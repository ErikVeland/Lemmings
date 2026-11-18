# Ultimate Lemmix website

Canonical origin: https://lemmings.glasscode.academy

The site uses the existing GenErik DJ static publishing approach on Glasscode.
Its design follows Lemmix: sky, grass, stone, little characters and real captures.
Archivo provides readable text. The actual product logo retains its artwork.
There are no trackers, third-party embeds, contact forms or remote font requests.

## Build and review

1. Run `python3 Website/build.py`.
2. Run `python3 Website/check_site.py`.
3. Run `python3 Website/serve.py`.
4. Open `http://127.0.0.1:4391`.

Normal builds use the Python standard library and committed assets.
Asset preparation requires Pillow, FontTools and Brotli. Its source records live
in `image-provenance.json`. Do not replace genuine captures with mock interfaces.

The page shell and navigation are in `build.py`. Page bodies are in `content`.
The tiny optional script switches real platform screenshots. All text, navigation,
the first capture and alternative image links remain available without it.

## Publication

Use the dedicated deployment scripts in `deploy`. Keep every existing Glasscode
site and game-service endpoint unchanged. Publish a committed site revision and
retain the previous release for rollback. Verify HTTPS, every route, the missing
page status and canonical metadata at the public origin after publication.

The app remains a release candidate. A live website is not App Store approval.
Use the stable support, privacy, privacy choices and accessibility routes in
App Store Connect only after those public URLs pass verification.
