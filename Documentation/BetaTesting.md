# Public testing

The current 1.5 build 49 notes describe a local, registered-device test. They
do not certify a public beta. Freeze one source commit and use a new build number
for the next public candidate. Earlier package records do not certify it.

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

Lemmings 2 and Lemmings 3 remain Preview. NeoLemmix remains Beta or Preview.
Physical Intel, minimum-macOS, complete VoiceOver, physical-controller and
sustained performance checks remain separate from automated checks.

[Report a problem](https://github.com/ErikVeland/Lemmings/issues/new) with the
build number, Mac model, macOS version, game and level, settings, input device,
and steps to reproduce. Include a screenshot or replay when it helps.

## Build locally

```sh
zsh Scripts/build-local-app.sh
open ".build/local/Ultimate Lemmings.app"
```

This builds both Mac architectures with the installed local game assets.
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
RELEASE_TAG=v1.5-build50 \
MONTEREY_WORKTREE=/path/to/clean-release-worktree \
UPDATES_DIR="$PWD/.build/release50-updates" \
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
inputs without building or uploading. `RELEASE_BASE` defaults to `v1.2-build41`
for version 1.5.

`NOTARY_KEYCHAIN` selects another keychain. Apple ID authentication uses
`APPLE_ID` and `APPLE_TEAM_ID`, with a secure password prompt. App Store Connect
API-key authentication uses `ASC_KEY_PATH`, `ASC_KEY_ID` and `ASC_ISSUER_ID`.
Keep credentials outside Git.

`Scripts/package-beta.sh` is the historical beta packager. Its legacy notes
naming and full closure gate do not match the current public tester workflow.
Use `build-and-notarise.sh` for this release.

## Validate and publish

```sh
python3 Tools/ReleaseReadiness/audit.py --app --scope classic-1.0
zsh Scripts/run-music-timing-tests.sh
zsh Scripts/run-music-catalogue-tests.sh
zsh Scripts/run-adaptive-dj-playback-tests.sh "$PWD/Sources/Music"
TEST_ARCH=x86_64 zsh Scripts/run-app-integration-tests.sh
```

Review failures and open gates before publishing. A regression audit does not
certify all hardware or complete the preview campaigns. Record each remaining
limit in the release evidence and notes.

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
