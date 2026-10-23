# Public testing

The current public Mac release is 2.2.1 build 98. See its
[release notes](ReleaseNotes-2.2.1-build98.md) and
[release checks](ReleaseReadiness/2.2.1-build98/README.md).
iPhone/iPad/Duo build 21 is Waiting for Review. Apple TV build 11: Waiting for Review
Apple processing and Beta Review determine external tester availability.
Freeze one source commit for each public candidate; earlier records do not
certify a new package.

## Newcomer and veteran playtests

This protocol supports the [2.1 foundation priorities](2.1Roadmap.md#priorities-and-acceptance).
Recruit a small varied group of children with a guardian, adults unfamiliar with
games, returning players and veterans. Participation and observation need their
agreement. No recruitment or completed human session is recorded by this update.

Use a fresh disposable profile and record the exact build, language, device and
input. Keep the player's ordinary saves separate. Let the first thirty minutes
run without unsolicited coaching. Use the existing Journey and introductory
levels. Experienced players may move on through the existing free Try later path.

Observe these tasks in order:

1. Start play from Home and identify the entrance and exit.
2. Select a skill and give it to a lemming facing the intended direction.
3. Describe what changed after the assignment.
4. Pause and use basic Zoom before earning any stars.
5. Make an ordinary mistake, recover and choose another idea.
6. Open help and identify whether it is level-specific or general coaching.
7. Request one further hint deliberately, then return to the same paused state.
8. Finish a level and identify the primary next action without interpreting career rewards.
9. Defer a difficult Journey lesson and find it again.
10. Quit, return the next day and resume the same run and owner.
11. Play one Hot Seat handover and wait for the next player's Ready.
12. Repeat the key input, pause, help and recovery tasks in L2 and L3, recording their current limits.

Record confusion, accidental assignments, recovery, voluntary retries, helpful
hints, unwanted spoilers and whether the player asks to continue. Completion time
and clears alone cannot measure discovery. Ask what the player noticed before
asking about stars, names, music or emotion. Do not treat visible frustration as
an instruction to reduce every puzzle's difficulty.

Compare optional character/effect presentation enabled and disabled, varying the
order across participants. Confirm that wants are understood as optional fiction,
that ordinary failure remains safe and funny, and that a valid one-star clear
feels successful. Human-review translated onboarding, hint availability and
failure/recovery copy. Retain anonymised findings and actionable changes in the
release evidence only with participant agreement.

Automated preparation stays offscreen and muted through Tools/UITestRunner/run.py.
Physical input, real screen-reader use, audible tone, HDR appearance, live sync and
sustained device loads need separate human/device records. This protocol does not
authorise foreground automated tests, audible tests, invitations or publication.

## Public beta boundary

Do not send a Game Center snapshot to an open tester group. It is development
signed for registered Macs and cannot pass notarisation. Use a Developer ID
signed, notarised archive for a public beta. Check the downloaded archive with
Gatekeeper on a clean Mac before inviting testers.

If the beta uses a direct download, keep it separate from the stable Sparkle
feed. State that updates are manual. Confirm the bundled game and soundtrack
assets are approved for public distribution. Record known preview limits in
the beta notes.

## Local build and notarisation

After the current source, notes and proof gates pass, run the tri-archive
release script:

The public app supports Intel and Apple silicon Macs with macOS 12.3 or later.
It includes the bundled campaigns, fan packs and soundtrack catalogue. No extra
game files are needed for those campaigns. Optional external NeoLemmix styles
use a separately selected folder. Game Center is disabled in the public app.
Local records remain available.

Existing installations can use **Ultimate Lemmings → Check for Updates…**.
Keep a backup of saved runs before testing an upgrade. Use copies for recovery
tests. Do not overwrite your only copy with an older release.

## What to test

Before it builds, the script checks for source changes after the previous
release, requires tracked notes for the exact build, and checks that the
Monterey worktree contains the current commit. It does not create missing
notes. It then writes three timestamped ZIP files to
`~/Downloads`: Developer ID standard, macOS 12 Monterey and Game Center.

Classic and Lemmings 2 retain their Complete classifications.
Lemmings 3 and NeoLemmix remain Beta.
Physical Intel, minimum-macOS, complete VoiceOver, physical-controller and
sustained performance checks remain separate from automated checks.

[Report a problem](https://github.com/ErikVeland/Lemmings/issues/new) with the
build number, Mac model, macOS version, game and level, settings, input device,
and steps to reproduce. Include a screenshot or replay when it helps.

## Build locally

```sh
LEMMINGS_ARCHITECTURES="$(uname -m)" zsh Scripts/build-local-app.sh
ditto ".build/local/Ultimate Lemmings.app" "$HOME/Downloads/Ultimate Lemmings.app"
```

For a quick manual test build, set `LEMMINGS_ARCHITECTURES="$(uname -m)"` and
copy the finished app to Downloads. Skip automated tests and notarisation for
that build. Universal builds are for public release candidates.
For a quick, current-architecture Game Center snapshot:

```sh
zsh Scripts/build-game-center-snapshot.sh
```

The snapshot uses an Apple Development signature and a provisioning profile.
It runs only on registered Macs. It always includes the full soundtrack from
`Sources/Music`, reusing converted files in `.build/music-aac`. It is not notarised
and is not the public download.

## Prepare a release

1. Set the build number and write the matching release notes.
2. Build the local app with the current assets.
3. Run `Scripts/verify-trolley-maxima.sh` and `Scripts/generate-level-hints.sh`.
4. Run the relevant engine, audio, input, recovery and app checks.
5. Commit the release source, assets metadata, proofs, hints and notes.
6. Prepare a clean Monterey worktree at the same commit, with local asset paths.
7. Run the release script with a separate update directory for the new build.

```sh
NOTARY_PROFILE=lemmings-beta \
RELEASE_BASE=v2.0.2 RELEASE_TAG=v2.0.3 \
MONTEREY_WORKTREE=/path/to/clean-release-worktree \
UPDATES_DIR="$PWD/.build/release-2.0.3/updates" \
zsh Scripts/build-and-notarise.sh
```

The script validates the reviewed notes. It does not create missing notes.
It builds Developer ID standard, Monterey and Game Center archives in Downloads.
Standard and Monterey are universal apps with the same macOS 12.3 minimum.
The separate Monterey build does not prove execution on physical Monterey hardware.
Both public-capable archives are notarised, stapled and checked with Gatekeeper.
The Game Center archive stays local to registered testers.

The script also checks rescue proofs, hints, app integration, fresh-user launch,
source consistency and the signed Sparkle feed. `--dry-run` checks the initial
inputs without building or uploading. Set `RELEASE_BASE` explicitly.
Run `zsh Scripts/run-localisation-tests.sh` for the catalogue and picker gate.

`NOTARY_KEYCHAIN` selects another keychain. Apple ID authentication uses
`APPLE_ID` and `APPLE_TEAM_ID`, with a secure password prompt. App Store Connect
API-key authentication uses `ASC_KEY_PATH`, `ASC_KEY_ID` and `ASC_ISSUER_ID`.
Keep credentials outside Git.

`Scripts/package-beta.sh` is the historical beta packager. Its legacy notes
naming and full closure gate do not match the current public tester workflow.
Use `build-and-notarise.sh` for this release.

## Validate and publish

```sh
python3 Tools/ReleaseReadiness/audit.py --app --scope minor
zsh Scripts/run-music-timing-tests.sh
zsh Scripts/run-music-catalogue-tests.sh
zsh Scripts/run-adaptive-dj-playback-tests.sh "$PWD/Sources/Music"
TEST_ARCH=x86_64 zsh Scripts/run-app-integration-tests.sh
```

Review failures and open gates before publishing. A regression audit does not
certify all hardware or complete the preview campaigns. Record each remaining
limit in the release evidence and notes.

Use `--scope all` when engine or content changes can affect campaign outcomes.
The signed shipping-app launch check requires the real desktop and a separate
explicit request. Offscreen tests do not close that gate. Keep all automated
mechanical checks muted through the repository runner.

Publish the notarised update ZIP, stamped Markdown notes, BBCode notes and
checksums. A public tester release is a GitHub prerelease. Verify the public
download and a real Sparkle update before treating distribution as complete.
See [Automatic updates](AutomaticUpdates.md) for the publication checks.

## Game Center testing

Game Center requires a separate development-signed archive and a provisioning
profile that includes each tester's Mac. Keep the device roster and profile out
of the public release attachments. See [Game Center setup](GameCenterSetup.md).
The Developer ID app uses local records and needs no device registration.

Read [third-party notices](../THIRD_PARTY_NOTICES.md) for content provenance and
distribution scope. The owner authorised this public tester release.
