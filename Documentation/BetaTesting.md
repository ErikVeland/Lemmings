# Beta testing

This page tells you how to make a beta build and how a tester opens it.

## Beta 4

Beta 4 is version `0.1`, build `4`. It includes the new application icon.
The tester package is `LemmingsLocal-0.1-beta4.zip` for Intel and Apple silicon
Macs running macOS 13 or later. The slim package retains the game music modules
and omits the studio soundtrack recordings.

The build number in `Resources/Info.plist` also sets the beta number in the
package filename. Increase it before each new beta release.

## Make a build

Run this command in the project directory:

```sh
zsh Scripts/package-beta.sh
```

The script builds the app, signs it, and writes a zip file. The script prints
the path and the size of the zip file at the end.

To leave out the studio soundtrack recordings, set `BETA_SLIM` first:

```sh
BETA_SLIM=1 zsh Scripts/package-beta.sh
```

A slim build is about 128 MB. A full build is about 504 MB. The recordings are
the difference. The game modules stay in both builds, so every level has music.

## Sign the build for other computers

macOS blocks a downloaded app that Apple has not notarized. An unsigned build
runs on your computer. It does not run on the computer of a tester.

The script finds the Developer ID in your keychain and signs the app with it.
Notarization uses an App Store Connect API key. The key is already stored in
the keychain under the profile name `lemmings-beta`.

To make a notarized build, set the profile:

```sh
BETA_SLIM=1 BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
```

The script uploads the build, waits for Apple, and staples the ticket to the
app. A stapled app passes Gatekeeper with no network connection.

App-specific passwords do not work for this account. Use the API key.

To store the key again on another computer, use the key file, the key ID, and
the issuer ID:

```sh
xcrun notarytool store-credentials lemmings-beta \
  --key AuthKey_MNWTSU7QGZ.p8 --key-id MNWTSU7QGZ \
  --issuer 7b152c28-1a8d-4980-834f-7cb8530365b0
```

## Instructions for a tester

Send these four steps with the zip file.

1. Download the zip file.
2. Double-click the zip file to unpack it.
3. Move `Ultimate Lemmings.app` to your Applications folder.
4. Open the app.

A notarized build opens with no warning and needs no other step.

If you send a build that is not notarized, macOS stops it. The tester must then
run this command one time:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

## What to test

The app needs no other files. All game data is inside the app.

Report these things:

- The level and the game where a problem happens.
- The artwork, music, and sound settings in use.
- Whether the problem repeats after a restart.

## Before you distribute

The app contains commercial game data. Read `THIRD_PARTY_NOTICES.md` first.
Keep the test group private and small.
