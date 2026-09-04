# Beta testing

This page tells you how to make a beta build and how a tester opens it.

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
Notarization needs one more step, which you must do yourself. The command asks
for an app-specific password.

1. Make an app-specific password at <https://account.apple.com>.
2. Store the credentials one time:

   ```sh
   xcrun notarytool store-credentials lemmings-beta \
     --apple-id wigwammultimedia@mac.com --team-id 54WU29TRTY
   ```

3. Run the script again with the profile:

   ```sh
   BETA_NOTARY_PROFILE=lemmings-beta zsh Scripts/package-beta.sh
   ```

The script then uploads the build, waits for Apple, and staples the ticket.
After this, the zip opens on any Mac with no warning.

## Instructions for a tester

Send these four steps with the zip file.

1. Download the zip file.
2. Double-click the zip file to unpack it.
3. Move `Lemmings Local.app` to your Applications folder.
4. Open the app.

If the build is not notarized, macOS shows a warning. The tester must run this
command one time:

```sh
xattr -dr com.apple.quarantine "/Applications/Lemmings Local.app"
```

After this command, the app opens normally.

## What to test

The app needs no other files. All game data is inside the app.

Report these things:

- The level and the game where a problem happens.
- The artwork, music, and sound settings in use.
- Whether the problem repeats after a restart.

## Before you distribute

The app contains commercial game data. Read `THIRD_PARTY_NOTICES.md` first.
Keep the test group private and small.
