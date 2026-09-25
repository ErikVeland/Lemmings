# Automatic updates

Ultimate Lemmings 1.5 uses Sparkle 2.7.3 for macOS updates.

## Runtime contract

- The app checks the HTTPS appcast once per day.
- Sparkle downloads and installs signed updates in the background.
- The app verifies the Ed25519 archive signature before extraction.
- The app shows `Check for Updates…` in the application menu.
- The feed URL and public key are in the app bundle `Info.plist`.

The private Ed25519 key stays in the release operator's login Keychain. Never
commit the key or pass the key value as a command argument.

## Release procedure

1. Build and notarise the standard Developer ID app with
   `Scripts/build-and-notarise.sh`.
2. Keep the generated update ZIP in the persistent `UPDATES_DIR`.
3. Set `PUBLISH_GITHUB_RELEASE=1` to upload the update ZIP, create or update
   the tagged GitHub Release, and publish `appcast.xml` to `main`.
4. Install the previous release and run the update check.
5. Record the source revision, archive checksum, appcast checksum and result.

The update ZIP must contain only the notarised app. The Game Center archive is
not an update candidate.

Publishing requires an authenticated GitHub CLI and a clean worktree. The
default tag for version 1.5 is `v1.5.0`. Set `RELEASE_TAG` when another tag is
required.

## Validation evidence

[Build 41 verification](ReleaseReadiness/1.2Build41Distribution.md) records the last
public Sparkle download, installation and relaunch. Repeat this check for 1.5.

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
