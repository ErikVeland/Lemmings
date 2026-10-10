# Apple Game Center and spatial audio setup

Worldwide community rankings are hosted on GlassCode and work without Game Center.
See [Hosted rankings](HostedRankings.md) for deployment, replay storage and consent.
The app also includes an optional GameKit integration and a ranked board catalogue.
The capability build enables Apple scores after validating its profile.
The build uses an installed matching profile automatically.
Without that profile, the ad-hoc build keeps only Game Center disabled.
The local result and career screens work without Game Center.

## Prepared configuration

`Resources/GameCenter/leaderboards.json` contains 178 exact ranked configurations
from the bundled rescue catalogue. Each configuration has Most Saved and Fastest clear boards.
Three additional boards rank career stars, distinct clears and three-star levels.
The file freezes the star thresholds for this board version. Use new board IDs if
the rules or thresholds change.

`Resources/GameCenter/app-store-connect-boards.json` lists all 359 prepared Apple
board IDs, names, score units, ranges, and four leaderboard sets. It is a setup
manifest, not an Apple API import file. Each set contains at most 100 boards.
Rescue and career boards sort from highest to lowest. Speed boards sort from
lowest to highest, retain the best score, and store positive simulation milliseconds.
Fastest 100% requires the whole run population, including clones, to be rescued.
Failed runs and rewind-assisted runs cannot submit speed scores. Rescue level scores
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
2. Create the four leaderboard sets and 359 classic leaderboards from the manifest.
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

The generator `python3 Scripts/prepare-game-center.py` prepares boards from the
current rescue catalogue and refuses output above Apple’s 500-board limit.
The checked-in 178-configuration release catalogue is deliberately retained;
expanding it needs a board allocation or a hosted service.
Set `ENABLE_APPLE_CAPABILITIES=0` to force an ad-hoc build with Game Center
disabled. Hosted rankings remain available. The default `auto` mode uses a valid matching profile when available. The code uses APIs available on macOS 13.

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

Apple allows at most 500 boards per app. Both speed categories across the
existing catalogue would require 537, so only Fastest clear IDs are prepared for
Game Center. Fastest 100% is available locally and on the hosted community boards. The client supports optional ascending Fastest 100% IDs, but
the release configuration does not assign them. See [Apple’s board limits](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboard-sets).

The new speed IDs are prepared locally; they still require registration in App
Store Connect. This change does not enable live service or claim those boards
are deployed. The current ranked catalogue stays at 178 configurations.

Local speed records retain movies through the existing replay store and expose
playback on their leaderboard rows. Older times remain ranked when a movie was
never retained; those rows show playback as unavailable. Playback suspends the
active engine audio when opened from results.

The Game Center integration does not upload movies, attempt histories or local initials.
The separate, opt-in GlassCode service uploads selected records and available movies.
Hosted board rows link to those movies. Game Center rows do not have replay links.
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
using event positions relative to the visible camera. Lemmings 2 now uses eight
independent mono sources through the same renderer, preserving its native sample
rates and pitches. The vertical view spans 60 degrees. Panning, resizing and
precision zoom move the listener for both new and still-playing sounds.
Offscreen sources retain their side and become quieter with distance. Nearby
duplicate cues collapse into one voice per 32-pixel region, while opposite sides
remain distinct. Interface clicks and countdown warnings remain centred.
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

Classic positions death, rescue, entrance, skill and builder-warning events. L3
positions deaths, rescues, assignments and each placed brick. L2 positions native
death, building, assignment, entrance, projectile and interaction cues. L2 still
has no mapped exit cheer. Recorded replay audio remains a mono mix rather than a
recording of the live spatial renderer.

Offline checks render a sustained sound while the camera moves past it, and
verify left/right energy, offscreen attenuation, duplicate handling, mute and
pause backlog. Native input checks run through the offscreen, muted UI runner.
The camera-key checks passed in all three engines, including repeat suppression,
text and modifier guards, rendered help and button targets. The L2 runtime suite
passed all 120 level-load checks, 73 recorded completion fixtures and its
survivor carry-over checks after adding event positions.
Listening on headphones and speakers, personal profiles, and full release replay
proof validation remain separate checks. L2's source change adds sound positions
only, but its source fingerprint changes and needs the normal release audit.

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

## Shared backend: anonymous rescue totals

The same host also runs the separate anonymous
telemetry protocol in Tools/Telemetry/server.py and AnonymousTelemetry.swift.
Opted-in clients send fixed aggregate events to POST /v1/event. GET /v1/saved
returns the lifetime global saved count. Individual profile names, replay IDs
and player account identifiers do not belong in this counter.

Keep these aggregates separate from authenticated leaderboard submissions and
replay evidence. Anonymous client counts cannot certify a per-level maximum.
A stronger rescue target needs a completion replay checked against the matching
level data, engine and starting conditions. Winning replays with losses establish
best-known targets; only a supported upper-bound proof establishes optimality.

The current telemetry service suppresses its own client-address logs. Deployment
must also configure proxy logs and provider retention consistently with the
privacy notice. The anonymous counter is deployed at
https://glasscode.academy/lemmings-api. The public total is GET /v1/saved.
The independent systemd service is lemmings-telemetry on loopback port 8796.
Source is installed under /opt/lemmings-telemetry. Aggregate state is under
/var/lib/lemmings-telemetry, managed by systemd. The root-only admin credential
is /etc/lemmings-telemetry.env; never bundle that credential with the game.

Deployment files are in Tools/Telemetry/deployment. Stage that directory with
its parent server.py, then run deployment/install.py as root. It keeps a dated
copy of the existing website configuration under /var/backups/lemmings-telemetry,
validates Nginx before reloading, and restores the website configuration if
activation fails. Changes are confined to the new route and service.

The service and its Nginx route do not log request addresses. Nginx strips
forwarded identity headers and cookies. Cloudflare still terminates public
traffic; provider-level processing is distinct from the identifier-free stored
aggregates. The database is capped at 16,384 pages (64 MiB with its default
4 KiB pages), and the service has memory, CPU and task limits. This uses the
existing server plan and certificate, with no new paid subscription.

Resources/Info.plist configures future builds to use this endpoint. Sharing stays
opt-in. LEMMINGS_TELEMETRY_URL can override the endpoint at build time.
The installed Session Test 18 application is unchanged.

Authenticated worldwide rankings and replay uploads are deployed separately under
/lemmings-api/rankings. They do not feed this aggregate counter. Uploaded movies
are community playback records, not independently verified rescue targets.
