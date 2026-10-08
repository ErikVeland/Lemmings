# Hosted worldwide rankings

The live service is `https://glasscode.academy/lemmings-api/rankings`.
It uses the existing GlassCode server and TLS certificate. There is no additional
paid service or Game Center requirement. Game Center remains an optional separate
board provider when the app has the required Apple configuration and signature.

The app's Worldwide page opens these community boards by default:

- Fastest clear and Fastest 100%, measured in simulation milliseconds.
- Most saved and Least skills.
- Career stars, Levels cleared and Three-star levels.

Level boards compare the complete level/physics conditions fingerprint. Career
boards take the best successful rescue per game, pack and level. Every board
separates runs with rewinds from runs without rewinds. Failed runs and zero-time
results cannot enter speed boards. Fastest 100% requires the actual population,
including created clones, to be saved. Ties use rescues, skills, time and a stable
record order. The service shows one best record per player, with five rows per page.

## Sharing and playback

Browsing requires no account. **Share as XXX** explicitly enables sharing for that
local player. The consent line identifies the public data: initials, scores and
available replays. A random credential is stored in the macOS Keychain for each
local player. The server stores only its SHA-256 digest. No Apple account, email
address or installation-wide player identity is required.

The app uploads the best candidates for each board and each successful rescue.
Completed runs stay local first. Retained record movies upload after scores.
Failed syncs retry on the next completion or when the player opens or refreshes
the worldwide page. Older records without retained movies remain eligible for
rankings, with replay playback unavailable. Movies use the shared playback route
for Classic, NeoLemmix, Lemmings 2 and Lemmings 3. Result-screen playback suspends
the active engine's audio through its existing callback.

**Remove shared records** disables sharing and removes that player's hosted
records and movies. A failed removal stays queued for the next connection.
Deleting a local profile also queues removal of its shared records. The existing
credential remains available to complete a queued deletion. Local scores and
movies remain available when removing only the shared copy.

These are **community records**, submitted by the client. A movie is playback
material, not a deterministic input replay or an anti-cheat proof. Public scores
cannot establish verified rescue maxima. Career stars use the server's shipped
completion catalogue, or the finite population ceiling. A catalogue update
reassesses stored stars when the service starts. This service does not modify
anonymous rescue telemetry or use that telemetry to rank players.

## Limits and operation

`lemmings-rankings.service` runs Python's standard-library HTTP server and SQLite
on loopback port 8797. Nginx routes only `/lemmings-api/rankings/` to it. The existing
`/lemmings-api/` telemetry route still uses its separate service and database.

- Code and completion catalogue: `/opt/lemmings-rankings`.
- Database and movies: `/var/lib/lemmings-rankings`, owned by systemd's dynamic user.
- Database cap: 32,768 pages, about 128 MiB with the default 4 KiB page size.
- Movie caps: 64 MiB per upload, 256 MiB per player and 1 GiB total.
- Registration/run caps: 10,000 players and 20,000 submissions per player.
- Process limits: 128 MiB RAM, 25% CPU and 40 tasks.
- Nginx uses a shared 20 requests/second bucket with a burst of 40.

No API access logs are retained by the service or its Nginx location. Forwarded
IP headers and cookies are stripped. Cloudflare still processes public traffic;
this is separate from the application's storage policy. Credentials must never
be added to logs, documentation or the app bundle.

Movie capacity errors leave scores shared and movies local. The UI reports that
some replays remain local. Operators can increase the constants after reviewing
available disk space. There is no automatic eviction of existing public movies.
The host had approximately 14 GiB free at deployment. No unrelated files were
removed. State survives service restarts; a separate off-host backup is not
configured by this deployment. Back up the database with SQLite's online backup
API and copy the movie directory when adding the service to host backups.

## Deploy and check

Stage `Tools/Rankings/server.py`, `Resources/Trolley/verified-maxima.json` and
`Tools/Rankings/deployment/` together, then run `deployment/install.py` as root.
The installer saves the previous route, unit, code and catalogue under
`/var/backups/lemmings-rankings/<timestamp>`. It checks Nginx and the loopback health
endpoint before reloading the proxy. Activation failure restores the prior files.

The app reads `HostedRankingsURL` from `Resources/Info.plist`. New builds use the
live URL. Existing installed test apps do not acquire this integration from a
server update alone; the Session Test 18 app was not replaced by this deployment.

Run focused checks:

```sh
python3 -m unittest discover -s Tools/Rankings -v
LEMMINGS_TEST_AUDIO=muted swift test --filter HostedRankingsTests
zsh Scripts/run-trolley-tests.sh
python3 Tools/Rankings/smoke.py https://glasscode.academy/lemmings-api/rankings
swiftc -parse-as-library Tools/Rankings/native-smoke.swift -o .build/hosted-native-smoke
.build/hosted-native-smoke https://glasscode.academy/lemmings-api/rankings
```

Native UI tests use the required offscreen runner and muted audio. The two live
smoke checks create a temporary player, upload a test score/movie, verify the API,
and remove the player and its data. Do not substitute a real player's credential.
