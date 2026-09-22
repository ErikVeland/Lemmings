# Beta testing

RC1 (build 36) is the current candidate: the first real-device test release since
beta 32, and the first build after the official Classic campaign closed at
352/352. See [RC1 readiness](Beta36Readiness.md) and
[release notes since beta 32](ReleaseNotes-beta36.md).

## Validate the build

Run from the project directory:

```sh
zsh Scripts/build-local-app.sh
zsh Scripts/run-app-integration-tests.sh
TEST_ARCH=x86_64 zsh Scripts/run-app-integration-tests.sh
zsh Scripts/run-beta-regressions.sh
zsh Scripts/run-swift-tests.sh
zsh Scripts/run-sequel-mac-artwork-tests.sh
zsh Scripts/run-explosion-hdr-tests.sh
zsh Scripts/verify-official-classic.sh --include-conversions
zsh Scripts/run-cross-build-recovery-tests.sh
zsh Scripts/verify-trolley-maxima.sh
```

Integration tests use their own app identifier and preferences, plus assets from
the local app bundle. The Swift Testing runner works around stale Command Line
Tools manifest interfaces in a local copy; it does not modify the installed tools.

`Scripts/verify-official-classic.sh` replays the committed witness manifest and
requires all 292 official routes; `--include-conversions` adds the 60 Oh Yes!
routes and the combined 352-level quest, restore and progression checks. This
gate is closed as of beta 35 — see [ClassicOneZero.md](ClassicOneZero.md).

`Scripts/run-cross-build-recovery-tests.sh` checks that saved runs and Hot Seat
games survive an engine change across builds. Run it before any release that
touches engine or recovery code; restore copies of real checkpoints first, never
the owner's live Checkpoints folder.

## Package for testers

```sh
BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
```

The script checks the release-scope gate (`Tools/ReleaseReadiness/package_scope.py`),
builds both architectures, signs with the Developer ID in the keychain, submits
to Apple, staples the ticket, and checks the extracted zip with Gatekeeper.
Version 1.0 and later refuses to package while a required Classic gate is open.
Earlier zip files move into `.build/local/archive/`.

"Cut a build" means a local Game Center build only, unless the owner asks for
all three archives (Developer ID standard, macOS 12 Monterey, Game Center). A
tri-archive cut is what "for real device testing" or "for testers" means: the
Developer ID and Monterey archives run on any tester's Mac, not just the two
registered Game Center devices.

For a package without recorded soundtracks:

```sh
BETA_SLIM=1 BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
```

The slim package retains module music. Both variants use the same filename;
keep only the intended variant in the handoff folder. Always notarize the
variant you distribute.

## Package the macOS 12 (Monterey) archive

The Monterey build lives on the `macos12-support` branch, kept as a worktree at
`.claude/worktrees/macos12`. It merges each release's gameplay and doc changes
from the working branch, then builds with the 12.3 deployment target from
inside that worktree:

```sh
cd .claude/worktrees/macos12
git merge <working-branch>
BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
```

Merge every commit from the working branch first, including saved-run and
recovery fixes — an out-of-date Monterey merge can reintroduce a bug the
working branch already fixed. Check with
`git log <monterey-branch>..<working-branch> --oneline` before packaging.

## Package with worldwide rankings

The Developer ID archive above has Game Center turned off. Apple does not allow
App Store Game Center services under a Developer ID signature, so the packaging
script disables the leaderboard catalogue and drops the provisioning profile.
Testers of that archive keep local records only.

To test worldwide rankings, build the Game Center variant:

```sh
BETA_GAME_CENTER=1 \
APPLE_PROVISIONING_PROFILE="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/<profile>.provisionprofile" \
zsh Scripts/package-beta.sh
```

Select the profile that covers every device in BetaTesters.md. The automatically
selected installed profile can be older than the downloaded two-device profile.

This build uses an Apple Development signature and carries the profile. It runs
only on the Macs that the profile lists. [Beta testers](BetaTesters.md) is the
roster that profile must match. It writes
`UltimateLemmings-<version>-beta<build>-gamecenter.zip` and leaves the Developer
ID archive in place.

Before a tester can use it:

1. Get the tester's Mac UDID. The tester finds it in **Apple menu → About This
   Mac → More Info → System Report → Hardware → Provisioning UDID**.
2. Add that UDID to the devices list in the Apple Developer portal.
3. Regenerate the `Lemmings macOS Development` profile and download it.
4. Rebuild with `APPLE_PROVISIONING_PROFILE` set to the new file.

Apple's notary service accepts Developer ID signatures only. This build uses an
Apple Development signature, so it cannot be notarized and Gatekeeper stops it on
first run. Each tester must clear the quarantine flag:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

The profile holds at most 100 Macs for each membership year. Worldwide rankings
in this build use the Game Center sandbox. Those scores stay separate from
production scores.

## Tester instructions

1. Unpack the zip.
2. Move `Ultimate Lemmings.app` to Applications.
3. Open the app.

No extra game files are needed for the bundled campaigns. Fan packs are included and new compatible packs are checked at launch.
Optional external NeoLemmix styles still use a separately selected folder.

Check a fresh profile and an upgrade from beta 32, the last archive most testers
have. Exercise all display modes, fullscreen and resizing, music-source changes,
mute, sound-bank changes, single-step completion, and transitions into and out
of the sequels. Check the sequel artwork setting during play and after relaunch.
Try nuke undo in the classic player and Lemmings 2. Check explosion flashes in
flat and CRT modes, including pausing during a flash and moving between
displays. Report the game and level, settings, and whether restarting changes
the result.

RC1 is this project's first release aimed at real, physical hardware coverage
rather than the developer's own Macs: report your exact Mac model, macOS
version, and whether it is Intel or Apple silicon on every report. Physical
Intel, macOS 13, HDR, multiple displays and high refresh rates are still
unverified — that is what this candidate exists to test.

The app contains commercial game data. Keep the beta test group private and
follow `THIRD_PARTY_NOTICES.md`.
