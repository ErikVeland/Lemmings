# Hosted worldwide rankings

The live service is `https://glasscode.academy/lemmings-api/rankings`.
It uses the existing GlassCode server and TLS certificate. There is no additional
paid service or Game Center requirement. Game Center remains an optional separate
board provider when the app has the required Apple configuration and signature.

The app's Worldwide page opens these community boards by default:

- Fastest clear and Fastest 100%, measured in simulation milliseconds.
- Most saved and Least skills.
- Career stars, Levels cleared and Three-star levels.

Results provide a direct **Worldwide** action. **Records > Worldwide** remains
available, including for older local records. Records without a conditions
fingerprint can browse community career boards but cannot select a level board.
Game Center is a separate provider selected from the community page.

Level boards compare the complete level/physics conditions fingerprint. Career
boards take the best successful rescue per game, pack and level. Every board
separates runs with rewinds from runs without rewinds. Failed runs and zero-time
results cannot enter speed boards. Fastest 100% requires the actual population,
including created clones, to be saved. Ties use rescues, skills, time and a stable
record order. The service shows one best record per player, with five rows per page.

## Sharing and playback

Browsing requires no account. Players who share play counts participate in
worldwide rankings automatically, unless they explicitly turned off record
sharing for that local player or removed its shared records. Launching the app
queues eligible saved records for all participating profiles. New results and
new action replays use the same queue across Classic, NeoLemmix, Lemmings 2 and
Lemmings 3. Turning count sharing off stops automatic submissions. An explicit
record-sharing choice remains independent. Removing shared records stays off
across count-sharing changes and restarts. **Share as XXX** can enable records
separately. The consent and Privacy pages identify the public data: initials,
scores and action replays. A random credential is stored in the Keychain for
each local player. The server stores only its SHA-256 digest. No Apple account, email
address or installation-wide player identity is required.

The app uploads the best candidates for each board and each successful rescue.
Completed campaign runs stay local first. Version 1.9.2 retains verified action
replays for Classic, NeoLemmix, Lemmings 2 and Lemmings 3. Sharing uploads the
command file after its score. Playlist and Journey results also retain profile
scores and can enter the worldwide queue. They keep their separate campaign
progress and turn ownership.

Each level category exposes action replays for its top ten entries, across the
first two five-row pages. Assisted and unassisted rankings remain separate.
Career totals have no single level replay. Game Center remains a separate
provider and does not attach these community action files. The server retains candidate action
files within its storage caps. It checks current ranks on every download, so a
run outside all four top tens is unavailable. A retained candidate can become
public again when its rank returns to the top ten.

Playback needs the matching level open with its original data. It copies that
level's starting simulation and renderer. The viewer offers Play/Pause, Restart,
Back/Forward one second, Step +1 and 1x/2x/5x speed. It stays paused on opening
and seeking. Closing returns to the board and restores the interrupted engine.
It never updates campaign progress, scores, saved runs or turn ownership.

Public JSON contains timed commands, run/conditions identities, the engine
fingerprint, initial/final state hashes and the expected outcome. It contains
no video, engine snapshot, level assets, source paths, profile ID or campaign
progress. Classic records assignments, rate changes and nuke. L2 also records
fan/aim state, pointer release, machine and chain input. L3 records assignments,
tool direction and End Run. NeoLemmix records assignments, interval changes and
nuke. Rewinds retain the surviving action branch and mark the ranking assisted.

The client reconstructs the entire run before retaining or opening a replay.
It rejects invalid actions, different initial data, changed engine identities,
incorrect rescue/population/skill totals and different final state hashes.
Seeking starts from the independent initial state when moving backwards.
A restored snapshot whose action log no longer proves the run remains eligible
for scores, with action playback unavailable.

Failed syncs retry on the next completion or when the player opens or refreshes
the worldwide page. Older records and movies cannot recover missing actions.
They remain eligible for rankings, with action playback unavailable. Local MP4
review/export and the legacy server movie endpoints remain compatible. The
1.9.2 client shares and plays action files on community boards.

**Remove shared records** disables sharing and removes that player's hosted
records, actions and legacy movies. A failed removal stays queued for the next
connection. Deleting a local profile also removes its local action files and
queues removal of its shared records. The existing credential remains available
to complete a queued deletion. Removing only hosted copies keeps local files.

These are **community records**, submitted by the client. Reconstruction checks
playback consistency. It does not establish server-verified anti-cheat proof or
verified rescue maxima. Career stars use the server's shipped
completion catalogue, or the finite population ceiling. A catalogue update
reassesses stored stars when the service starts. This service does not modify
anonymous rescue telemetry or use that telemetry to rank players.

## Limits and operation

`lemmings-rankings.service` runs Python's standard-library HTTP server and SQLite
on loopback port 8797. Nginx routes only `/lemmings-api/rankings/` to it. The existing
`/lemmings-api/` telemetry route still uses its separate service and database.

- Code and completion catalogue: `/opt/lemmings-rankings`.
- Database and replay files: `/var/lib/lemmings-rankings`, owned by systemd's dynamic user.
- Database cap: 32,768 pages, about 128 MiB with the default 4 KiB page size.
- Action caps: 8 MiB per upload, 100,000 commands, 120,000 ticks and 128 MiB per player.
- Legacy movie caps: 64 MiB per upload and 256 MiB per player.
- Combined replay storage cap: 1 GiB.
- Registration/run caps: 10,000 players and 20,000 submissions per player.
- Process limits: 128 MiB RAM, 25% CPU and 40 tasks.
- Nginx uses a shared 20 requests/second bucket with a burst of 40.

No API access logs are retained by the service or its Nginx location. Forwarded
IP headers and cookies are stripped. Cloudflare still processes public traffic;
this is separate from the application's storage policy. Credentials must never
be added to logs, documentation or the app bundle.

Replay capacity errors leave scores shared and replay files local. The UI reports that
some replays remain local. Operators can increase the constants after reviewing
available disk space. There is no automatic eviction of retained replay files.
The host had approximately 14 GiB free at deployment. No unrelated files were
removed. State survives service restarts; a separate off-host backup is not
configured by this deployment. Back up the database with SQLite's online backup
API and copy the replay directory when adding the service to host backups.

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
smoke checks create a temporary player, upload a test score, actions and a legacy
movie, verify the API, and remove the player and its data. Their synthetic actions
check transport only. They do not prove an engine outcome. Do not substitute a real player's credential.

## 1.9.2 action replay validation

The service changes need deployment before `/v1/actions/<runID>` and the optional
`actionReplay` board field are available. Startup adds `action_bytes` to the
existing database without replacing scores or movie references. No live service
or installed application was changed while developing this feature.

Focused native checks run with `TEST_SCOPE=action-replay` through
`Scripts/run-app-integration-tests.sh`. Keep the default offscreen runner and
muted audio. Service checks cover action ownership, immutable uploads, schema
restart, deletion, strict fields, input bounds, top ten category/assistance
separation, capacity failure and the HTTP hash contract.

On 2026-10-10, the focused native action-replay run passed offscreen with muted
audio. It checked independent reconstruction and seeking for all four engines,
rejected changed hashes/skills and invalid commands, and exercised live Classic
input recording with nuke undo. Temporary storage and fake transport checks
covered consent, action uploads without video, rank-ten downloads, corrupt
download rejection and profile deletion. Classic, L2 and L3 renders were
inspected at 1120 x 720 and 760 x 520, with target bounds, mouse hits, stepping,
play/pause, timed playback and speed-state checks. NeoLemmix engine reconstruction
was checked with a synthetic level. A separate NeoLemmix artwork render and a
complete live app-to-hosted-service run were not performed.

The 17 Python service tests passed. Both deployment smoke scripts were updated
for action upload/download and removal. Python syntax and native smoke compilation
passed. The live smoke scripts were not run. Local evidence is in
`.build/action-replay-ui-tests.log`, `.build/action-replay-server-tests.log` and
`.build/action-replay/screens/`.

Automatic sharing checks cover count-sharing activation, saved-record backfill,
all profiles and all four engines, offline retry, disabling sharing during
registration, explicit opt-outs, removal and restart. The five new checks pass
alongside the existing Journey and cloud-progress checks (21 tests in total).
Muted offscreen Mac checks cover Privacy on/off and consent at two widths.
The windowless mobile audit covers 36 phone, iPad and TV consent/on/off/unavailable
renders, complete captions and input targets. Mac source typechecking and both
mobile SDK module builds pass. These checks use injected transports and do not
upload real player records. Live delivery, device input and Keychain prompts
remain manual checks. New translated captions use explicit English fallbacks
pending human language review.
