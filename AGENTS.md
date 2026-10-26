# Repository ownership

`ErikVeland/Lemmings` is the canonical repository for this project.
Keep source, issues, app releases and artwork handoffs here. Do not create
separate repositories for downloads or exported assets. Publish supplemental
downloads as releases here, without replacing the latest app release.
Keep `main` as the default branch. See `Documentation/RepositoryLayout.md`
for the archived repositories and migration record.

# Interface changes

For work that changes visible UI, read `Documentation/UIPrinciples.md`.
The user requires clear icons and states without explanatory clutter.
Use familiar symbols, distinct state shapes, clear grouping and one primary
next action. Keep necessary action names and accessibility text. Do not add
sentences that repeat an icon, count, progress bar or visible result.
Verify the rendered states and their input targets before calling a UI change done.

Game UI must match the shipped pixel artwork. Read and reuse `GameControls.swift`,
`GameStoneButton` and the bitmap renderers before adding a control.

# Narrative and textual direction

Read `Documentation/NarrativeDirection.md` for the shared writing direction
across Classic, Lemmings 2 and Lemmings 3. `Documentation/NarrativeCopyAudit.md`
distinguishes implemented copy from proposed rewrites and records source coverage.
`Documentation/LemmingAssessments.md` records the frozen ten-word catalogue and
the identity rules that preserve personalities across retries and saved runs.

Consider these references for every narrative choice and textual direction
across the game:

- Widows Bay
- David Lynch
- Monty Python
- Sierra Adventure Games
- LucasArts Adventure Games, especially Monkey Island and Day of the Tentacle
- Are You Afraid of the Dark
- The Good Place
- Riget
- Eerie, Indiana
- Roald Dahl

Use these references to guide tone, humour, atmosphere, dialogue and flavour text.
Keep action names, instructions and accessibility text clear and usable.

# Cross-game parity

Treat QoL and Hot Seat behaviour as shared features across Classic, Lemmings 2
and Lemmings 3. Check all three engines when changing controls, turn ownership,
retry/continue actions, handovers, hints or saved-run navigation. Reuse shared
controls and flows. Keep handovers paused until the player is ready. Record
engine-specific limits and validation gaps instead of silently omitting support.

# Cross-platform parity

Applicable features must work on Mac, iPhone, iPad, Duo and Apple TV, including
supported NeoLemmix content. Adapt input, layout and file transfer to each
platform without silently dropping capabilities. Prefer shared feature logic
and renderers. Check every affected engine and platform when adding or fixing
a feature. Keep deliberate platform exceptions explicit, including the user's
TV effects budget. Record source gaps separately from physical-device and
service acceptance. Maintain `Documentation/PlatformFeatureParity.md` as the
current source-backed register. Older release notes and historical port plans
do not establish current parity.

# Save, sync and resume trust

Save, sync and resume are core features. Preserve the session ID, player roster,
next turn, queue position, completion records and compatible checkpoint across
saves and reopenings. Starting another route must not publish a journey deletion.
Home must resolve saved queues for the selected session, including archived queues.
Never report Synced while a surviving journey lacks the roster needed to restore it.
Keep automated test saves outside production storage. During persistence work,
verify reopen, offline/reconnect and cross-device import with isolated saves.
Preserve recovery evidence before repairing user saves. Separate source validation
from hosted-service verification and physical-device acceptance.

# Release schedule

Follow `Documentation/ReleaseSchedule.md`. The owner's priority order is:

1. Ship the Mac release quickly. Skip tests unless the candidate changes an engine.
2. Deliver iOS.
3. Deliver tvOS.
4. Deliver sideloading stores and installers from `Documentation/IOSDistribution.md`.

Publish each platform when ready. Lower-priority delivery must not delay Mac.
For a Mac candidate without engine changes, skip test suites and test-running
release audits. Keep required build, signing, notarisation, package and feed
verification. For engine changes, run affected engine checks under the release
replay policy. Record skipped checks explicitly. This policy supersedes older
routine-release test requirements.

# Local test builds

A request for a test build means a quick local build for manual testing.
Build only for the current Mac architecture. Bypass automated tests, audits,
Intel compilation and notarisation. Put the app in Downloads immediately.
Run release audits and universal builds only for public releases.

# Test windows

Run native UI tests through `Tools/UITestRunner/run.py`. Keep its default
offscreen mode so tests do not cover the playfield or take desktop focus.
All automated testing must stay headless and in the background while the user
tests gameplay. Mechanical tests must mute all music, sound effects, replay audio
and alert sounds. Keep the runner's default `LEMMINGS_TEST_AUDIO=muted` in every
window mode. Do not change system volume or saved game audio settings to silence
tests. Audible audio tests require a new explicit user request.
Report failures and checks that cannot run headlessly back to Codex. Do not launch test windows, switch displays, take focus or show error
dialogs. Secondary-display and foreground runs require a new explicit user
request. Do not run them automatically as a fallback.

# Transitory write-ups

Keep posts, forum threads, social media drafts and other one-off write-ups out
of the repository. Write them to `~/Documents/Ultimate Lemmings/Posts`. The
repository keeps only material that stays current: feature docs, roadmaps, the
current release notes and release evidence that a gate or roadmap cites.
