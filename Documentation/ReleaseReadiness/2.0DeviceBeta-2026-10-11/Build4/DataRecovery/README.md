# iPad bundled campaign recovery

The owner reported missing game data and confirmed Developer Mode enabled.
Apple's app query showed version 2.0 build 1 at a new installed bundle URL,
replacing the previously verified build 4. The default Xcode build had no
`IOS_BETA_CONTENT_DIR`, so its content phase omitted the bundled campaign.
This matches the reported missing-data state.

The frozen signed build 4 contains the verified 26 Classic files and 120 levels.
It was reinstalled without uninstalling the app or removing its data container.
Apple's subsequent query confirms version 2.0 build 4. The frozen IPA hash is
`a5a67f154f8806002b2bbc5692a3c5f11175ec76cc942c3fe2f65bbaae4b8b70`.

Normal Xcode Debug builds now stage the local Classic source when available.
They include only approved data files and exclude original executables.
A frozen `IOS_BETA_CONTENT_DIR` always takes precedence. Missing local data keeps
an import-only build. Invalid local data fails the build. Release builds still
require an explicit staged content path. Set `IOS_LOCAL_CLASSIC_DATA_DIR` to an
empty value for an import-only Debug build.

All 65 release-tooling tests pass headlessly and muted. A normal unsigned Debug
arm64 device build without a beta-content override succeeds. Its manifest
matches signed build 4 exactly and covers all 26 files and 120 levels.
The current workspace also contains newer mobile camera changes, recorded in
`source-manifest-after.json`. The restored candidate remains frozen. Build 5
was rejected after further source changes. [Build 6](../../Build6/README.md) uses
a frozen source copy, includes the captured camera/artwork changes, and is
installed with its exact version and build confirmed by Apple.
Manual UIKit acceptance remains open. No automatic app launch, audible test,
foreground test window or TestFlight upload occurred.

Evidence: [before](before-apps.json), [build 4 recovery](delivery.json),
[installed build](apps.json), [Debug campaign](debug-content.json),
[source boundary](source-manifest-after.json), [tests](release-tooling-tests.log).
