# One game codebase, two publication profiles

Ultimate Lemmings and Ultimate Lemmix use one source tree and one marketing
version. Implement features and fixes once in the shared application modules.
Build each publication profile from the same source revision.

The separate targets contain publication configuration: asset policy, bundle
identity, signing, update channel and Store artwork guards. They do not contain
separate gameplay or interface implementations. Development belongs on the
shared main branch through the normal merge-request workflow. Edition-specific
long-lived feature branches are not part of this design.

`Resources/Publishing/editions.json` owns the marketing version and publication
metadata. Each destination retains its existing build-number sequence. A
different build number does not select different game source.

## Shared source boundaries

| Source | Both publication profiles use |
| --- | --- |
| Engines and services | The same `Sources/` modules and `Package.swift` |
| Mac application | The same `Sources/LemmingsLocal` frontend and Mac compilation helper |
| iOS and tvOS launch | `Apps/SharedAppleMobile/AppDelegate.swift` and `LaunchURL.swift` |
| Top Shelf | `Apps/SharedAppleMobile/TopShelf/ContentProvider.swift` |
| Desk Clock widget | `Apps/DeskClockWidget/DeskClockWidget.swift` |
| iOS launch checks | `Apps/SharedAppleMobile/UITests` |

The publication profiles select bundled resources, application identifiers,
signing, services and update channels. Ultimate Lemmix also requires the Store
artwork compilation condition in the application and its Swift package targets.
`StoreBuildGuard.swift` makes a missing package condition fail compilation.
Edition conditions do not belong in `NxlvKit`.

The existing resource provider selects licensed defaults or imported owned
assets. Importing assets retains the same application code. See
[Ultimate Lemmix](UltimateLemmix.md) for asset coverage and acceptance limits.

## Build commands

Run these commands from the repository root. They build local products and do
not upload or publish them.

Check both publication profiles without compiling the game:

```sh
zsh Scripts/build-publication.sh --check
```

Set the marketing version and destination build counters in
`Resources/Publishing/editions.json`. Then update the generated project values:

```sh
zsh Scripts/build-publication.sh --sync
zsh Scripts/build-publication.sh --check
```

Inspect a build command before running it:

```sh
zsh Scripts/build-publication.sh --dry-run ultimate-lemmix ios \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Use `ultimate-lemmings` or `ultimate-lemmix` as the edition. Use `macos`, `ios`
or `tvos` as the platform. For example:

```sh
zsh Scripts/build-publication.sh ultimate-lemmings macos
zsh Scripts/build-publication.sh ultimate-lemmix macos

zsh Scripts/build-publication.sh ultimate-lemmix ios \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/publications/ultimate-lemmix/ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

The Mac commands retain each existing packager's resource and signing inputs.
For a current-architecture preservation build, set `LEMMINGS_ARCHITECTURES` to
the current architecture. The Lemmix Mac packager requires
`ULTIMATE_LEMMIX_ALTERNATIVE_RESOURCES`. It refuses to replace an existing
Downloads app. Follow the repository's local-build and release policies.

Prepare the licensed mobile resource profile before its first build:

```sh
python3 Apps/UltimateLemmixSupport/prepare_resources.py \
  --output .build/publication-resources/ultimate-lemmix \
  --alternative-resources /path/to/verified/alternative/resources
```

Use the TV destination `generic/platform=tvOS` for a `tvos` build.
`Apps/UltimateLemmixSupport/build.sh` remains a compatible entry point and
delegates to the publication command.

## Drift checks and build records

The publication check validates all six destination profiles. It rejects stale
versions, incorrect application identities, copied launch sources, different
package roots and missing Store guards. It also rejects edition conditions in
the engine and original-media build phases in the licensed mobile targets.
The command rejects overrides of profile-owned identity, Info.plist, entitlements
and artwork conditions. Destination and signing-team options remain available.
The selected profile sets the artwork mode independently of the parent shell.

Both Mac editions use `Scripts/build-mac-sources.sh`. Its recursive source list
includes new Swift files in every existing module. Cache records include source
content, compiler, SDK, target, flags, build helpers and compiled output hashes.
Normal builds refresh stale code. Partial builds reject stale dependencies.

The common publication command records each build under
`.build/publications/EDITION/PLATFORM/last-build.json`. The record includes the
shared-source fingerprint, source revision, command and compiler result.
A source or manifest change during compilation makes the command fail.
Compare successful records when preparing both editions from the same revision.

The `Shared publication contract` CI workflow checks source membership, metadata,
publication commands and compiler-cache behaviour. These checks use isolated
fixtures and a fake compiler. They do not require commercial game data.

## Validation limits

Local checks cover publication metadata, all mobile project source memberships,
the shared launch URL contract and both Mac source lists. Both Mac editions
currently select the same 531 Swift source files. Focused compiler-cache tests
cover nested source additions and stale inputs. Shared mobile entry points and
the Store guard also passed SDK type checks.

This consolidation changes build configuration and launch-source ownership.
It does not change engine rules or replace existing app bundles, release feeds
or historical evidence. No new packaged app, device acceptance, hosted CI run
or Store submission forms part of these checks.
