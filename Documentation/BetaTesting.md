# Beta testing

Beta 20 is the current candidate: version `0.1`, build `20`, for Intel and Apple silicon on macOS 13 or later. See [beta 20 notes](ReleaseNotes-beta20.md). Beta 19 must not be distributed.

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
zsh Scripts/verify-classic-completion.sh
zsh Scripts/verify-campaign-completion.sh
zsh Scripts/verify-trolley-maxima.sh
```

Integration tests use their own app identifier and preferences, plus assets from
the local app bundle. The Swift Testing runner works around stale Command Line
Tools manifest interfaces in a local copy; it does not modify the installed tools.
The campaign gate checks the committed witness manifest before replaying the
known solutions. Use `Scripts/verify-campaign-completion.sh --require-all` to
require a solution for every level. That stricter gate is expected to fail while
campaign coverage remains incomplete; a passing known-solution gate is not a
full-campaign sign-off.

## Package for testers

```sh
BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
```

The script builds both architectures, signs with the Developer ID in the
keychain, submits to Apple, staples the ticket, and checks the extracted zip
with Gatekeeper. Earlier zip files move into `.build/local/archive/`.
The default archive is `.build/beta20/standard/UltimateLemmings-0.1-beta20.zip`. The checked frozen beta 13 is under `.build/beta13/package/`. Release notes are included in the zip and beside it.

For a package without recorded soundtracks:

```sh
BETA_SLIM=1 BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
```

The slim package retains module music. Both variants use the same filename;
keep only the intended variant in the handoff folder. Always notarize the
variant you distribute.

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

Check a fresh profile and an upgrade from beta 13. Exercise all display modes,
fullscreen and resizing, music-source changes, mute, sound-bank changes,
single-step completion, and transitions into and out of the sequels.
Check the sequel artwork setting during play and after relaunch. Try nuke undo
in the classic player and Lemmings 2. Check explosion flashes in flat and CRT
modes, including pausing during a flash and moving between displays.
Report the game and level, settings, and whether restarting changes the result.

The app contains commercial game data. Keep the beta test group private and
follow `THIRD_PARTY_NOTICES.md`.
