# Bundled NeoLemmix packs

Date: 28 September 2026
Status: approved by the owner

## Decision

The owner decided on 28 September 2026 to bundle the NeoLemmix CE 1.2.0 levels
in all builds, the same way the app bundles LLDB fan packs. CE `License.txt`
permits the style images to be copied only to run NeoLemmix. The owner
therefore chose to bundle only the 26 styles that `License.txt` assigns to DMA.
These styles are conversions of the original assets that the owner approved on
15 September. A background updater for community packs is a later change.

## Content

- Source: NeoLemmix CE at commit `38d0449f87501798e78ac668a9494848f4aa9649`.
  The release zip has only 12 styles, so the script reads the git checkout.
- `Scripts/prepare-neolemmix-content.sh [CE_CHECKOUT]` checks the commit and a
  clean `data/external`. Without an argument, it clones the pinned commit into
  `.build/neolemmix-ce`.
- The script copies `data/external/levels/`, the 26 DMA styles and
  `License.txt` into `Content/NeoLemmix/`. Git ignores `Content/`.
- The script excludes community styles, CE interface graphics (`gfx/`),
  executables, sound and music. The unused Stoner mask in `gfx/mask` is not
  needed: `NeoLemmixSpriteSet` accepts a missing mask.
- `manifest.json` records the commit, the style list and the level counts.

## Bundling

- `bundle-game-data.sh … all` copies `Content/NeoLemmix/` to
  `Resources/NeoLemmix/`. The build stops when the manifest is missing.
- The bundle adds about 25 MB.

## App behavior

- `BundledGameResources.neoLemmix(in:)` returns the bundled levels and styles.
- `NeoLemmixLibrary.discover` lists the bundled source first, then the player
  folder from **Add NeoLemmix Packs…**. A later pack with the same pack ID does
  not appear.
- Each level gets the first styles root that has every style it names. The
  level source's own styles come first. This check reads only the level: 2.1 s
  for the bundle, against 20.5 s for full piece resolution. Full resolution
  still runs when the level starts.
- A level without a styles root shows as **Unavailable**. Starting it explains
  that it needs community styles.
- The home NeoLemmix entry opens the browser without a folder prompt.

## Saved runs

- Restore finds `neoPackID` and `neoLevelID` in the library first, then falls
  back to `sourcePath`. An app move or a removed CE copy does not strand a run.
- Retry keeps the styles root of the running level.
- The changed-source check stays in place.

## Measured content

CE `levels.nxmi` manifests list 788 of the 794 level files.

| Pack | Levels | Ready with DMA styles |
| --- | --- | --- |
| Lemmings Redux | 160 | 156 |
| NeoLemmix Introduction Pack | 120 | 65 |
| Original Lemmings | 508 | 492 |
| Total | 788 | 713 |

## Tests

- `NeoLemmixLibraryTests`: bundled priority, duplicate pack IDs, per-level
  styles roots and lookup by IDs.
- `BundledGameResourcesTests`: 26 styles, the licence, 3 packs, 788 levels, and
  713 ready levels that each resolve fully.
- `AppIntegrationTests` (`TEST_SCOPE=neo-pack`): no folder prompt, 75
  unavailable levels, and restore by IDs after the saved path is removed.

## Out of scope

- The community-pack updater.
- iOS and Monterey packaging.

## Rights note

CC BY-NC 4.0 does not permit commercial use. A paid release needs a separate
permission from the CE authors.
