# Automatic updates

Ultimate Lemmings 1.6 uses Sparkle 2.7.3 for macOS updates.

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

Public 1.5 build 50 is recorded in [its distribution evidence](ReleaseReadiness/1.5Build50Distribution.md).
The integrated 1.6 build 51 candidate is local. Its appcast must be published only
with its matching signed and notarised archive.

## Player experience

Compatible updates discovered by Sparkle add a pixel download icon to the shared
home screen. Scheduled checks use a quiet reminder. Selecting the icon or
**Check for Updates** opens Sparkle's release notes and update controls. Skipping
a version clears its reminder. A failed network check does not invent availability.

Automatic downloads and installation remain supported. Bundled **What's New**
notes appear once after each upgrade, even if installation did not show an alert.
The build is acknowledged only when the player continues. Notes also remain in Help.
On first launch, the play-style choice precedes the optional soundtrack chooser.
For returning players, upgrade notes precede that chooser. Audio settings can reopen
soundtrack downloads at any time.

## Release procedure

1. Freeze the source and assets.
2. Run `Scripts/build-and-notarise.sh` without publication.
3. Check the printed ZIPs, stamped notes, signed appcast and release gates.
4. Set `RELEASE_TAG`, `RELEASE_VERSION`, `RELEASE_COMMIT` and
   `RELEASE_NOTES_PATH` from the package run.
5. Run `Scripts/publish-github-release.sh --check` with the printed update ZIP path.
6. For public tests, create a GitHub prerelease with the exact tag and frozen commit.
7. Publish the verified ZIP and attachments. Update `main/appcast.xml` with the signed feed.

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
| Apple signature | Developer ID signature verifies |
| Notarisation | Gatekeeper accepts the unpacked archive |
| Installation | The app relaunches at the new build number |
| Recovery | The previous app remains usable when the update fails |
