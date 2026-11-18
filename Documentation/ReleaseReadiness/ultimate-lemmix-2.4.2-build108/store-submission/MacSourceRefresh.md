# Mac source refresh

The universal Mac archive passed verification on 19 November 2026. Store export requires a credential-access check after the Mac is unlocked.
The signed package in Handoff remains unchanged. No replacement package was produced from the current source.

The archive uses commit `1ac19c638e3f62dd48f7d4dedf17b285b961b079` and stable Xcode 27.1.
Both architecture builds reused verified NxlvKit core caches. The shared libraries, app and widget compiled successfully.
The clean resource inventory, source hashes, development signatures, entitlements and archive checks passed.
The current app source did not change during compilation. Concurrent website edits account for the dirty checkout flag in build evidence.

The source change replaces a complex presentation expression with explicit loops for older Swift compilers.
All 9,600 generated artwork bytes remain identical, with SHA-256 `9483b3013bdaaaaafdebf56fced501c71cb8b4e99973f47c057241116ee28a78`.
No engine source changed. Test suites and notarization did not run under the Store release policy.

Xcode export returned exit code 70. It reported a missing `Xcode-Username` credential and `No Accounts`.
The Mac was locked when credential access failed. This does not establish that an account was deleted.
Unlock the Mac, then check Xcode account access before attempting another sign-in.
The environment and available local signing identities remain unchanged.
No account or keychain entry was changed by this task. The archive remains available for an export-only retry.

After credential access is confirmed, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Tools/Publication/mac_store.py export   --build-dir /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/mac   --architectures arm64 x86_64 --automatic-export
```

Replace the Handoff package only after the export, Apple analysis and exact package checks pass.
The prior signed package remains in `mac-before-ci-compatibility-20261119/Export` and Handoff.
Its SHA-256 is `9010fcb80bd8c905dbdb402e8b9c24c4c937aeb0f165936f00baf61cfd448920`.
The [refresh receipt](mac-source-refresh.json) records the verified archive and retained package paths.
