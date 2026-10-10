# Automatic updates

Ultimate Lemmings uses Sparkle 2.7.3 for macOS updates.

## Runtime contract

- The app checks the HTTPS appcast once per day.
- Compatible updates add a download icon to the home screen. Selecting it opens
  Sparkle's release notes and update controls.
- Automatic updates are supported and enabled by default in 1.6. Sparkle respects
  the player's saved update preferences. Automatic downloads bring the release
  notes forward, and bundled notes appear after an upgrade.
- Earlier builds retain their own update preferences until the upgrade finishes.
- The app verifies the Ed25519 archive signature before extraction.
- The app shows `Check for Updates…` in the application menu.
- The feed URL and public key are in the app bundle `Info.plist`.

The private Ed25519 key stays in the release operator's login Keychain. Never
commit the key or pass the key value as a command argument.

## Current releases

Public 1.9.1 build 76 is the current release. The
[1.9.1 distribution record](ReleaseReadiness/1.9.1Build76Distribution.md) covers
the notarised archives, signed live feed and validation limits. Publish an
appcast only with its matching signed and notarised archive.

Public releases require a slim fresh-install download. It includes the
54 essential music versions and offers missing optional libraries on first
launch. Libraries already downloaded to Application Support are retained.
The full archive remains the Sparkle fallback because older apps also store
optional music inside the app bundle. Moving those updates to slim packages
requires a migration that preserves that music before Sparkle replaces the app.

Signed delta updates reuse unchanged files in the installed full bundle, including
the soundtrack. Sparkle downloads a full archive only when no matching delta is
available or its application fails. A delta made from the full bundle cannot patch
a slim bundle with a different file tree. See Sparkle's
[delta update contract](https://sparkle-project.org/documentation/delta-updates/).

## Player experience

Compatible updates ready for Sparkle to present add a pixel download icon to the shared
home screen. Scheduled checks use a quiet reminder. Selecting the icon or
**Check for Updates** opens Sparkle's release notes and update controls. Skipping
a version, dismissing the alert or ending a failed session clears its reminder.
A failed network check does not invent availability.

Version 1.9 retains a single manual request while Sparkle is busy
checking the feed or downloading automatically. Both entry points use that request;
it runs when Sparkle's `canCheckForUpdates` becomes true. Further clicks can bring
existing update controls forward. This fix ships in 1.9. It follows Sparkle's
[gentle reminder lifecycle](https://sparkle-project.org/documentation/gentle-reminders/).

Run `TEST_SCOPE=updates zsh Scripts/run-app-integration-tests.sh` for the muted,
offscreen regression checks. They exercise busy checks, repeated clicks, automatic
notes, session cleanup and home icon input targets without downloading or installing
an update. A public archive installation and relaunch remain separate release checks.

Automatic downloads and installation remain supported. Bundled **What's New**
notes appear once after each upgrade, even if installation did not show an alert.
The build is acknowledged only when the player continues. Notes also remain in Help.
On first launch, the play-style choice precedes the optional soundtrack chooser.
For returning players, upgrade notes precede that chooser. Audio settings can reopen
soundtrack downloads at any time.

## Release procedure

1. Freeze the source and assets.
2. Run `Scripts/build-and-notarise.sh` without publication.
   Keep the previous shipped full ZIP available. `generate-appcast.sh` finds it
   in the update directory or `.build/release-*/updates`. For another location,
   set `PREVIOUS_UPDATE_ZIP` to that ZIP. Generation stops if the previous published
   build is unavailable. Sparkle generates and signs the delta beside the full ZIP.
3. Check the printed ZIPs, stamped notes, signed appcast and release gates.
4. Set `RELEASE_TAG`, `RELEASE_VERSION`, `RELEASE_COMMIT`, `RELEASE_NOTES_PATH`
   and `DOWNLOAD_ZIP` from the package run. `DOWNLOAD_ZIP` is the notarised slim
   archive. It is required, even when the full update archive is ready first.
5. Run `Scripts/publish-github-release.sh --check` with the printed update ZIP path.
6. For public tests, create a GitHub prerelease with the exact tag and frozen commit.
7. Publish both ZIPs and every delta referenced by the new item before updating
   `main/appcast.xml`. The publication script checks the delta files and sizes,
   requires a delta from the previous published build, and uploads those assets.
   Generation preserves earlier feed entries, download URLs, signatures and notes.
   Delta filenames use ASCII letters, digits and hyphens so GitHub retains them.

8. Install public 1.2 build 41.
9. Run the update and check its relaunch.
10. Record the source revision, archive checksum, appcast checksum and result.

`publish-github-release.sh` creates a normal release by default. For a public
test, create the prerelease first, then set `RELEASE_APPROVED=1` and run the
script to upload its ZIP and feed. The release owner must have authorised publication.

The update ZIP must contain only the notarised app. The Game Center archive is
not an update candidate.

Release packaging requires a clean worktree. Publication is a separate step
and needs an authenticated GitHub CLI. The package script uses `v1.6.0` for
the feed URL by default. The tag must match the approved release version.
The publication script requires the tag and stamped notes. Its read-only
`--check` mode checks that the notes, archive name and signed appcast describe
the same build. Only the publication run needs `RELEASE_APPROVED=1`.

## Validation evidence

[Build 41 verification](ReleaseReadiness/1.2Build41Distribution.md) records the last
public 1.2 Sparkle download, installation and relaunch. The
[1.5 record](ReleaseReadiness/1.5PublicRelease.md) tracks the new check.

Run the data-independent checks before a release. The empty-feed option is
only for development before the first public update exists.

```sh
zsh Scripts/check-release-inputs.sh --allow-empty-appcast
```

The release script runs the strict form after it generates the signed feed.
The strict form rejects an empty appcast.

Record these results for each release:

| Check | Required result |
| --- | --- |
| Appcast URL | HTTPS and publicly reachable |
| Archive URL | HTTPS and matches the uploaded asset |
| Ed25519 signature | Present and accepted by Sparkle |
| Delta | Signed; patches the shipped base to the new signed app; publicly reachable |
| Apple signature | Developer ID signature verifies |
| Notarisation | Gatekeeper accepts the unpacked archive |
| Installation | The app relaunches at the new build number |
| Recovery | The previous app remains usable when the update fails |
