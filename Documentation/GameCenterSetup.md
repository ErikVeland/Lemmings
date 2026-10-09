# Apple Game Center and spatial audio setup

The app includes a GameKit integration and a ranked board catalogue.
The capability build enables worldwide scores after validating its profile.
The build uses an installed matching profile automatically.
Without that profile, the ad-hoc build keeps worldwide scores disabled.
The local result and career screens work without Game Center.

## Prepared configuration

`Resources/GameCenter/leaderboards.json` contains 178 exact ranked configurations
from the bundled rescue catalogue. Each configuration has a Most Saved board.
Three additional boards rank career stars, distinct clears and three-star levels.
The file freezes the star thresholds for this board version. Use new board IDs if
the rules or thresholds change.

`Resources/GameCenter/app-store-connect-boards.json` lists all 181 configured Apple
board IDs, names, score units, ranges, and two leaderboard sets. It is a setup
manifest, not an Apple API import file. Each set contains at most 100 boards.
All boards sort from highest to lowest and retain the best score. Level scores
are rescued counts. Equal rescue counts use Apple's tie handling. Local boards
also use skills and time, so tied worldwide positions can differ.

`Resources/GameCenter/GameCenter.entitlements` contains the Game Center
and Spatial Audio Profile entitlements. The signing script requests both. The registered App ID,
provisioning profile and signature must agree. An ad-hoc signature cannot enable
Game Center by adding this file alone.

## Enable live service

1. The owner enabled Game Center and Spatial Audio Profile for
   `academy.glasscode.lemmings`. Create or confirm the matching macOS app in
   App Store Connect and enable Game Center for its version.
2. Create the two leaderboard sets and 181 classic leaderboards from the manifest.
   Add the required localisations and score formats. Assign the boards to the sets.
3. Generate a macOS development provisioning profile with both capabilities.
   Include this Mac and the installed Apple Development certificate. Download it
   into Xcode's provisioning profile directory, or supply its path below.
4. For the fast local test loop, run `zsh Scripts/build-game-center-snapshot.sh`.
   It builds only the current Mac architecture and writes a ZIP to Downloads.
   The full universal build remains `ENABLE_APPLE_CAPABILITIES=1 zsh Scripts/build-local-app.sh`.
   Set `APPLE_PROVISIONING_PROFILE=/absolute/path/profile.provisionprofile` to
   select a profile explicitly. The script enables the bundled catalogue, embeds
   the matching profile, signs the library and app, and verifies both entitlements.
5. To sign an existing build, run
   `python3 Scripts/sign-capabilities.py ".build/local/Ultimate Lemmings.app"`.
   Add `--check` to validate prerequisites without modifying it.
   Game Center distribution requires the Mac App Store. Developer ID distribution
   does not provide Game Center. This development signing path does not submit
   the app to the store or complete its separate sandbox and distribution setup.
6. Test with an Apple sandbox account: connect, complete a ranked level, verify
   all three career boards and the level board, disconnect, improve offline,
   reconnect, and confirm the improved scores. Also test account changes and
   a different local player. Submit the Game Center components for release.

Recreate the disabled setup files with `python3 Scripts/prepare-game-center.py`.
Set `ENABLE_APPLE_CAPABILITIES=0` to force an ad-hoc build with worldwide scores
disabled. The default `auto` mode uses a valid matching profile when available. The code uses APIs available on macOS 13.

## Player identity and retries

The first explicit **Connect Game Center** action links the selected local player
to the signed-in Game Center account on this Mac. Other local profiles can view
worldwide boards but do not publish into that account. Changing the Apple account
clears the displayed ranks and requires connection again.

Completed attempts save locally before submission. While linked and connected,
new records sync after completion. The stored history supplies retries after a
network failure or an app restart. A successful sync suppresses duplicate score
submissions for that session. Scores outside the ranked catalogue, changed level
conditions, failed runs and rewind runs are excluded.

The app does not upload movie files, attempt histories, or local initials.
Game Center provides the displayed player name. Scores are client submissions;
Game Center authentication does not make them server-verified solutions.

## Sources

Apple documents the app registration, capability and signing requirements in
[Initializing and configuring Game Center](https://developer.apple.com/documentation/gamekit/initializing-and-configuring-game-center).
The leaderboard implementation follows
[Encourage progress and competition with leaderboards](https://developer.apple.com/documentation/gamekit/encourage-progress-and-competition-with-leaderboards).
The reward design uses visible stars and direct replay goals, with level and
career rankings, as illustrated by the
[Angry Birds Trilogy leaderboard structure](https://support.activision.com/angry-birds-trilogy/articles/the-angry-birds-trilogy-leaderboards).

## Spatial sound effects

Classic and Lemmings 3 effects use a fixed pool of mono sources through
`AVAudioEnvironmentNode`. The game places each source across a 120-degree arc
using its existing screen pan. Lemmings 2 effects use a centred mono source.
Music keeps its existing stereo mix. Automatic rendering selects processing for
supported output hardware. The signed spatial profile entitlement lets Apple's
renderer use the listener's personal profile when one is available.

This does not implement head tracking. The personal profile is managed by the
system and the app does not read or store biometric profile data. Without a
profile, effects still use the environment renderer. Wired output may require
system headphone configuration for the appropriate rendering mode.

Run `zsh Scripts/run-spatial-audio-tests.sh` for offline rendering, direction,
restart, and lifecycle checks. Personalised output still needs a listening test
with compatible headphones and a provisioned build.

Apple documents [personal spatial audio profiles](https://developer.apple.com/documentation/phase/personalizing-spatial-audio-in-your-app),
[mono spatial sources](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode),
and [macOS distribution limitations](https://developer.apple.com/macos/distribution/).

## Development activation on 11 September 2026

The Apple portal generated `Lemmings macOS Development` for team `54WU29TRTY`.
It expires on 11 September 2027 and includes both capabilities. The profile is
installed in the local Xcode profile directory. The universal app in
`.build/local/Ultimate Lemmings.app` was signed with the matching Apple Development
identity. Its signature and both entitlements passed verification.

The macOS 1.0 version in App Store Connect has Game Center enabled. All 181
classic leaderboards have English (U.K.) localisations, best-score submission,
integer scores, descending order, and the catalogue score limits.
`Ranked Rescue 1` contains 100 boards and `Ranked Rescue 2` contains 81.
Both sets have English (U.K.) localisations. All 181 created IDs match the local
manifest. The components remain in Prepare for Submission for development
testing. Public release requires App Review. The three-star board ID is
`ul.v1.career.three_star`, because Apple permits letters, digits, periods and
underscores in leaderboard IDs, but does not permit hyphens.

Validation passed: universal build, app integration suite, Trolley and Game
Center transport regressions, offline spatial rendering, audio lifecycle, profile
validation, and signature verification. The signed app launches. Live Game Center
sign-in and score submission still need a test account.

## Developer ID package correction

The private beta packager now forces the non-capability build before Developer ID signing.
It also honours `LEMMINGS_BUILD_DIR`, matching the local build script.
This avoids retaining a development provisioning profile or enabling Game Center in the direct-download package.
Local records remain available. Provisioned development builds still use the capability signing path for account tests.

Apple lists Game Center as an App Store service that is unavailable for Developer ID distribution:
[macOS distribution comparison](https://developer.apple.com/macos/distribution/).
The installed matching profile uses Apple Development signing. It is not a Developer ID distribution profile.
