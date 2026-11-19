# Ultimate Lemmix mobile targets

`UltimateLemmixIOS` and `UltimateLemmixTVOS` use the current full mobile and TV
application entry points. They retain the three engines, supported NeoLemmix
content, profiles, Hot Seat, saved runs, collections, Journey, records, hints,
controllers and settings. The iOS target embeds the Desk Clock widget. The TV
target embeds Top Shelf. Campaigns that require original data become available
after the player imports that data.

Both editions share their launch sources and application modules. The
[Lemmix manifest](../../Resources/Publishing/ultimate-lemmix.json) owns the version
and build counters. Keep this project on `release/ultimate-lemmix`. See [separate product releases](../../Documentation/SharedPublishing.md)
for the common build commands. Mac, iOS and tvOS use one App Store app identity.
Mobile extensions retain distinct identifiers:

| Product | Bundle identifier |
| --- | --- |
| iOS | `academy.glasscode.ultimatelemmix` |
| Desk Clock widget | `academy.glasscode.ultimatelemmix.iOSDeskClockWidget` |
| tvOS | `academy.glasscode.ultimatelemmix` |
| Top Shelf | `academy.glasscode.ultimatelemmix.TopShelf` |

The targets retain the existing iCloud container, Game Center capability and TV
App Group. Archive and export receipts must verify the service assignments for
the shared app identity and each extension. An unsigned SDK build does not verify
those services.

## Resource profile

Prepare a new output folder with the shared base preparer:

```sh
python3 Apps/UltimateLemmixSupport/prepare_resources.py \
  --output .build/publication-resources/ultimate-lemmix \
  --alternative-resources /path/to/verified/alternative/resources
```

This prepares current metadata, the native three-level starter, Lix media and the
licensed Lix font. It writes the trusted data inventory after font generation.
The build copies only the verified inventory. It excludes original media phases
and Mac icon formats. The widget receives its Lix artwork, font and notices.
The requested project icon remains a separate item that requires rights review;
its source and generated catalogue hashes are in `icon-source.json`.

The `Restore original assets` action installs a player-selected resource folder
outside the app. It retains the current app's trusted metadata and licensed
fallback. iOS uses application support. TV uses caches, which the system can
purge. The importer accepts data only. It grants no redistribution rights.
Individual Classic, Lemmings 2, Lemmings 3 and NeoLemmix import routes remain
available. Unreviewed fan-pack downloads are disabled in the Store profile.

## SDK build

Use the wrapper so the Store condition also reaches Swift package targets:

```sh
zsh Apps/UltimateLemmixSupport/build.sh ios \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/publications/ultimate-lemmix/ios/DerivedData CODE_SIGNING_ALLOWED=NO build

zsh Apps/UltimateLemmixSupport/build.sh tvos \
  -configuration Release -destination 'generic/platform=tvOS' \
  -derivedDataPath .build/publications/ultimate-lemmix/tvos/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The wrapper selects the installed Xcode for that process. It does not change
the system selection. `Store.xcconfig` is passed through `xcodebuild -xcconfig`.
The app and widget reference a declaration that exists only when GameArt is
compiled with `ULTIMATE_LEMMIX_STORE`. A package build with embedded original
control tiles therefore fails compilation. A consumer target flag alone is
insufficient.

These are separate products and build folders. Do not overwrite a running Mac
app. Local SDK compilation does not establish device acceptance, service
acceptance, distribution signing, App Store review or publication.
