# Repository layout

[ErikVeland/Lemmings](https://github.com/ErikVeland/Lemmings) is the canonical
repository for Ultimate Lemmings. Keep source, issues, app releases, music
libraries and exported artwork here. `main` is the default development branch.
App updates use the existing `main/appcast.xml` feed.

Publish supplemental downloads as releases in this repository. Set
`make_latest` to `false` so an artwork handoff or historical import cannot
replace the latest app release. Keep unpublished drafts as drafts.

## Download repositories

The public releases repository was consolidated on 21 October 2026. The private
artwork handoff still needs approval for publication. Each repository contained
one README commit, with downloads attached to GitHub releases. Neither held
additional app source.

| Original repository | Original purpose | Destination |
| --- | --- | --- |
| [UltimateLemmings-releases](https://github.com/ErikVeland/UltimateLemmings-releases) | Early signed RC downloads after a Dropbox link failed | [1.1 RC1, build 37](https://github.com/ErikVeland/Lemmings/releases/tag/v1.1-rc1) and the unpublished, empty `v1.0-rc1` draft |
| [Lemmings-Macintosh-Graphics](https://github.com/ErikVeland/Lemmings-Macintosh-Graphics) | Private Macintosh artwork handoff for NeoLemmix | Pending owner approval to publish the 8,809,286-byte ZIP in this public repository |

The original public releases repository is archived and links here. Its
existing release files remain available at their original URLs.

The artwork repository remains private and unchanged. Automatic approval
review rejected its upload because consolidation did not explicitly authorise
publication of the private payload. Its SHA-256 digest is
`1f4b404b57da0a2167a058cc5a707ab3d7ff2edf6688f6feddc238472fd25653`.
Obtain explicit approval before copying that ZIP into this public repository.

The [cursor bug report](https://github.com/ErikVeland/Lemmings/issues/23) and
all 12 comments were transferred to this repository.
GitHub redirects the original issue URL to the transferred issue.

## Preserved history and verification

The imported public release tag retains its exact commit ID. An archival tag
also preserves the original default branch:

| Tag | Original commit |
| --- | --- |
| `archive/UltimateLemmings-releases/main` | `eaa70809e7cb9c673d01a7b5c5e48a94cd935891` |

These imported tags preserve download-container README history. They do not
identify app source builds. Imported release notes retain the original text
below a dated migration notice.

The [consolidation verification](ReleaseReadiness/RepositoryConsolidation-2026-10-21.json)
records copied asset sizes and SHA-256 digests, the transferred issue, preserved
refs and archived repository. At the 21 October migration, all 36 existing app and music releases retained
their assets; `v2.1.1` was the latest app release and the migration left the feed
unchanged. Later app delivery is tracked in [release scope](ReleaseScope.md).
No app build or gameplay test was run for the repository migration itself.
