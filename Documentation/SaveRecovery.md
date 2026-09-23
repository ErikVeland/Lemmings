# Save recovery and upgrade migration

Updated 11 September 2026.

## Arcade records

The arcade store now keeps `records-v1.json.backup` beside `records-v1.json`. Each successful save retains the previous validated records. The first save also creates a backup.

If the primary file is unreadable or missing, the app validates the backup before restoring it. An unreadable primary is copied to a unique `records-v1.json.unreadable-…` file before replacement. The records page reports recovery and warns that recent results may be missing. The backup can be one save behind.

An unsupported version is not replaced with an older backup. If both files are invalid, the app preserves them and blocks record writes. The default location is `~/Library/Application Support/Ultimate Lemmings/Arcade/`. Preview builds use the existing preview directory.

Every write validates the records first. A file lock prevents overlapping writes by apps that use this store. A held lock causes a save error instead of waiting for the other app. A stale store also refuses to overwrite primary data that changed after it was loaded. Backup failures leave the primary unchanged.

A temporary save failure offers **Retry save** on arcade pages. Failed profile edits and player creation roll back their in-memory changes. The profile editor stays open, and Retry save retries the pending edit. The app changes profiles and closes the editor only after a successful save. A conflict with another app requires closing and reopening the app to load the newer records.

## Upgrade migration

The shipping app identifier is `academy.glasscode.lemmings`. Migration previously required `org.lemmingslocal.LemmingsLocal`, so the shipping build skipped standalone saves.

The current app now imports supported preferences and progress from the previous unified app domain, then missing bundled saves from the L2 and L3 standalone domains. The import includes:

- classic and sequel campaign progress, including profile namespaces;
- the eight L2 manual save slots and standalone sound choices;
- fan-level progress and the selected fan folder;
- saved settings, artwork choices, audio mute and the first-launch choice.

Current saved values take priority, including explicit `false` choices. Previous unified saves take priority over standalone saves. Registered defaults do not hide older saved choices. The importer does not modify the source domains.

A saved migration marker prevents later launches from restoring progress that the player has reset. Integration-test and standalone app identifiers do not import the unified app's preferences. Standalone saves tied to external data paths remain excluded, as before.

## Verification

Run `zsh Scripts/run-save-recovery-tests.sh` for fresh model and persistence checks. The release audit includes this suite. `--app` now includes the arcade-records suite as well.

The recovery tests cover validated backups, missing and corrupt primary files, preserved unreadable bytes, unsupported versions, invalid backups, stale writers, held locks, failed backup writes and successful retry. Migration tests use isolated preferences and verify the actual shipping identifier, domain priority, manual slots, profile namespaces, explicit choices and one-time import.

The arcade app tests exercise profile rollback and the Retry save button through mouse input. They also check that negative and oversized skill indices are rejected in classic and NeoLemmix sessions.

## Rewind and replay integrity

Rewind now tracks the number of commands actually applied to the current state. This fixes commands lost at keyframe boundaries, including tick zero. Normal playback and frame stepping reapply recorded commands after a rewind. A successful new action replaces the old future branch. Rejected assignments and unchanged release rates preserve it.

Replay export includes only the commands reached on the current branch. New recordings mark live input as occurring after its recorded tick. This preserves release-rate and nuke timing, including input before the first tick. Existing replay files retain their original timing rules.

Invalid rewind durations return failure without changing the simulation. Large finite durations clamp to the oldest available state.

`Scripts/run-classic-dos-rewind-tests.sh` checks state hashes across keyframe boundaries, replayed input, branch changes and JSON replay round trips. The existing replay suite checks compatibility with earlier recordings. These fixes establish the rewind history used by classic disk checkpoints.

## Remaining recovery work

Arcade backups protect profiles and records. The run checkpoints described below protect supported in-progress games. Campaign progress still uses its existing preferences storage. Installed-release migration trials, power-loss testing and cross-device save conflicts remain open.


## Classic run checkpoints

Classic campaign play now saves a checkpoint every five seconds of wall time.
Pausing, losing focus, sleeping, returning to the library and quitting request an immediate save.
Each run has its own file under `~/Library/Application Support/Ultimate Lemmings/Checkpoints/`.
A serial writer keeps periodic file writes off the game thread. Quit waits for pending writes.

**File → Resume Saved Run** (Shift-Command-R) offers the most recent checkpoint for the active player.
The app also offers it on launch after the initial play-style choice has been saved.
Restoration returns to the campaign and level, then replays the saved inputs against fresh level data.
It checks the engine fingerprint, initial level identity, command validity and final simulation hash.
The restored game stays paused. Selected skill, camera position, run identity and assistance counters remain.
Rewind history is rebuilt, including recorded future inputs after a rewind. Restoration does not start a new arcade attempt.
The previous movie recording is not restored. A new movie begins on the next attempt.

Checkpoint files have a version, payload checksum, atomic replacement, validated backup and non-blocking file lock.
A stale writer cannot replace newer data. Recovery preserves corrupt primary bytes.
An unsupported version remains untouched. Completing a run clears both checkpoint copies.
Missing or changed data is an error, not permission to resume a different level.

The checkpoint path now also covers NeoLemmix files and native L2 and L3 campaigns.
Power-loss and installed-release migration trials remain open.
Run `TEST_SCOPE=release-blockers Scripts/run-app-integration-tests.sh` for the replay, backup,
corruption, unsupported-version, stale-writer, controller remapping and live restoration checks.

## NeoLemmix and sequel checkpoints

NeoLemmix recovery retains the original file path, initial simulation, final simulation and input journal. The file and its styles must remain available and unchanged. Successful restoration compares the entire replayed simulation to the saved simulation before committing its restored simulation state. Queued release-rate changes and nuke undo are preserved. Opening a NeoLemmix file now enters the playing interface correctly.

L2 and L3 campaign recovery retains campaign progress, input history, selected action, camera and assistance counters. The app rebuilds the level from its original assets and checks both asset identity and replayed state. L2 includes assignments, fan and aim input, machines, chains and nuke undo. Held pointer input is released when a game is restored. L3 includes tool, direction and movement actions. Both restore paused without recording another attempt.

L2 state verification encodes runtime values deterministically, including private stored state. It excludes transient sound output and binds the file to the exact engine fingerprint. Recovery across a changed engine requires an explicit migration; it is not silently accepted. Replayed sound events are drained so resume does not play old sounds again.

Native campaigns save every five seconds and on pause, help, interruption, restart, level changes and close. Classic fan imports and L2 practice now also have checkpoints. Movie recordings are not restored.

Checkpoint reads and writes are limited to 64 MiB. Searching for the latest run ignores an unrelated damaged file when another valid run exists, while retaining the damaged bytes. If no valid run exists, the app reports the error.

The app integration tests exercise an actual NeoLemmix file through open, save and resume. The sequel UI tests round-trip checkpoint files with original game assets, verify continuation, preserve attempt identity and reject altered input journals. UI test executables share a process lock so test apps cannot steal focus from one another.


## Fan levels and L2 practice

Classic fan checkpoints retain the pack path, asset dataset, selected queue order
and current position. Resume rebuilds the current level and validates its simulation before
continuing. The pack must remain available. The restored run stays paused, retains
its selected skill and keeps its attempt identity. Leaving a fan run requests an
immediate checkpoint.

L2 practice checkpoints retain the training map and the chosen eight-skill panel.
Restore recreates practice play without applying its saved campaign progress to
the campaign. It restores the selected slot, pauses and retains the original attempt.
Invalid map indices, duplicate skills and incomplete panels are rejected.

See the [current recovery and campaign evidence](ReleaseReadiness/CampaignClosure-2026-09-22.md) for the retained baseline.

## Saved runs that cannot be restored

A saved run can become unusable. For example, its game data moved or a newer app
version wrote it. Resume then shows the error and **Discard saved run**.

- **Cannot restore run** discards that run.
- **Cannot read saved run** discards every run file that cannot be read.

Discarding moves the files to `Checkpoints/Set aside/`. The app does not delete them.
Resume then offers the next valid run, if one exists. If another app is saving
a run, the app reports it and offers no discard.

Deleting a player deletes that player's saved runs.

Validation: `Scripts/run-arcade-records-tests.sh` covers discard, unreadable
runs, deletion cleanup and the records way out.
