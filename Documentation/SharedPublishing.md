# Separate projects, synchronised shared code

Ultimate Lemmings and Ultimate Lemmix are separate projects with separate releases.
They share engines and feature modules in the canonical `ErikVeland/Lemmings`
repository. Sharing code does not combine their product identities or releases.

| Project | Release branch | Release metadata |
| --- | --- | --- |
| Ultimate Lemmings | `release/ultimate-lemmings` | `Resources/Publishing/ultimate-lemmings.json` |
| Ultimate Lemmix | `release/ultimate-lemmix` | `Resources/Publishing/ultimate-lemmix.json` |

Each release branch has its own working folder and tracked `Product.json` marker.
The marker identifies the product even in a detached checkout. Build entry points
reject the other product on a release branch or in a marked working folder.
`main` remains the default branch for shared integration. Do not merge the two
product branches together or remove their separate release identities.

## Independent release state

Each product owns its marketing version, platform build counters, bundle IDs,
asset policy, signing, service configuration and release channels. The shared
`Resources/Publishing/editions.json` file indexes the two product manifests.
It cannot define a common marketing version.

Ultimate Lemmings now ships Mac builds only. App Store updates are published
for Ultimate Lemmix only. Historical iOS and tvOS build counters in the Lemmings
manifest remain archival metadata; do not advance them or submit Lemmings builds
to App Store Connect. Keep the Lemmings Sparkle feed and Mac release tags
independent from Lemmix store releases.

Ultimate Lemmings retains its 2.4.3 candidate: Mac 107, iOS 46 and tvOS 21.
Ultimate Lemmix retains its documented 2.4.2 build 108 candidate on all platforms.
These values describe candidate metadata. They do not claim a new release.
Future releases can advance independently while using matching shared code.

The existing iOS and tvOS Xcode projects remain separate. Mac builds retain
separate app names, bundle identifiers, resource packagers and signing inputs.
Ultimate Lemmings retains its Sparkle feed and existing release tags.
Ultimate Lemmix must not publish into that feed or replace the latest Lemmings
release. Give any future Lemmix GitHub release an `ultimate-lemmix-` tag prefix
and keep `make_latest` false. Store submission remains product-specific.

## Keep shared changes in sync

Implement engine and shared feature fixes once through `main`. Merge the same
shared revision into each clean product working folder. Do not reset either
release branch to `main`, because that removes its product marker and release work.

Run these commands in each product folder:

```sh
git fetch origin
git merge --no-edit origin/main
```

Resolve any conflict before building or pushing. Preserve the local product
marker and its independently reviewed release metadata. Do not copy one
product's version, assets or signing configuration into the other product.

After updating both local branches, compare shared inputs from either folder:

```sh
python3 Tools/Publication/publication.py compare release/ultimate-lemmings
python3 Tools/Publication/publication.py compare release/ultimate-lemmix
```

The comparison checks engines, application modules, package dependencies,
shared mobile launch and test sources, the widget and the Mac compiler helper.
It reports changed paths and fails when shared inputs differ. Push both updated
branches after resolving shared drift. A product can ship independently once its
own platform and distribution checks pass.

Local asset folders, signing inputs and existing app bundles are not copied when
creating a working folder. Supply each product's existing approved build inputs.
Do not copy preservation media into the licensed Lemmix resource bundle.

The local Lemmix Mac test packager can include the owner's full collection.
Set `ULTIMATE_LEMMIX_LOCAL_GAME_RESOURCES` to an existing app's resource folder.
Set `ULTIMATE_LEMMIX_LOCAL_CONTENT` to the checkout's `Content` folder for current
fan and NeoLemmix levels. Set `ULTIMATE_LEMMIX_LOCAL_NEO_STYLES` to the local
NeoLemmix styles folder when those levels need community artwork.
These optional inputs apply to the personal Mac test build, not public releases.
The packager always generates and verifies the three starter levels.
The Lemmix logo and character default remain independent of the supplied levels.

## Product builds

Run commands from the matching product working folder. These commands build
local products. They do not upload or publish them.

Check both product contracts without compiling:

```sh
zsh Scripts/build-publication.sh --check
```

Update only the selected product's JSON file. Then synchronise only that product:

```sh
zsh Scripts/build-publication.sh --sync ultimate-lemmings
zsh Scripts/build-publication.sh --check --edition ultimate-lemmings
```

Use `ultimate-lemmix` for the Lemmix working folder. The sync command requires an
explicit product and does not rewrite the other product's metadata.

Inspect or run an Ultimate Lemmix iOS build:

```sh
zsh Scripts/build-publication.sh --dry-run ultimate-lemmix ios \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

zsh Scripts/build-publication.sh ultimate-lemmix ios \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/publications/ultimate-lemmix/ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Use `macos`, `ios` or `tvos` for the platform. A TV build uses
`generic/platform=tvOS`. `Apps/UltimateLemmixSupport/build.sh` remains a Lemmix-only
entry point. Mac builds use their separate existing packagers:

```sh
zsh Scripts/build-publication.sh ultimate-lemmings macos
```

Run the Lemmix command from its own folder:

```sh
zsh Scripts/build-publication.sh ultimate-lemmix macos
```

Follow the local-build and release policies in [AGENTS.md](../AGENTS.md).
The Lemmix Mac packager requires `ULTIMATE_LEMMIX_ALTERNATIVE_RESOURCES` and
refuses to replace an existing Downloads app. Prepare its licensed mobile
resources with `Apps/UltimateLemmixSupport/prepare_resources.py` before building.

## Verification and release guards

Product metadata checks validate each product against its own version and build
counters. A selected-product build does not require matching release metadata
for the other product. Shared-source checks continue to reject copied launchers,
missing Store guards, original-media build phases in Lemmix and product conditions
inside the engine.

Build records remain separate under
`.build/publications/PRODUCT/PLATFORM/last-build.json`. They record the product,
version, source revision, shared-source fingerprint and compiler result. Changes
to shared source or the selected product's metadata during compilation fail the
build. Changes to the other product's release metadata do not invalidate it.

The `Separate product release contracts` workflow checks both product contracts
on `main`, pull requests and the two release branches. Regression checks cover
independent versions, isolated updates, branch guards, detached product markers
and metadata changes during builds. These checks do not need original game data.

`Scripts/publish-github-release.sh` publishes Ultimate Lemmings only. Actual
publication requires `release/ultimate-lemmings` in addition to the existing
release-input and approval checks. Its read-only `--check` remains available
outside that branch. Lemmix release signing, Store acceptance and distribution
remain separate work. This branch separation publishes no app release.
