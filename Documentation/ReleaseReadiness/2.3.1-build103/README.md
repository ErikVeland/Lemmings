# 2.3.1 build 103 local Mac candidate

Status: local Apple silicon test app built and ad hoc signed on 30 October 2026. No public package or feed update has been made.

Source at start: `a7be9c525ac1a93825772d6d6d3bfdda34ec6b1d` on `main` plus the version, notes and What's New changes in this worktree. Release base: published Mac build 102 source `96dc81b8491dfdb58683f0e32025fc4c8137aa1c`, since the public `v2.3` tag still points to build 100. Platform numbers reserved: Mac 103, iOS 38, tvOS 17. See [candidate notes](../../ReleaseNotes-2.3.1-build103.md).

## Scope and checks

The Mac changes since the published build include Classic rewind history and scene rendering, Mac controls and navigation, save/Journey lookup and shared audio. Classic rewind history is an engine/replay change under [release schedule](../../ReleaseSchedule.md). A future public Mac package needs the affected engine/replay checks against its frozen source, plus universal signing, notarisation, package integrity and feed verification.

For this requested local test build, automated tests, release audits, Intel compilation and notarisation were deliberately skipped. The bundle uses the supported `main` music scope: 54 versions plus 31 original Macintosh arrangements. Game Center is disabled in the ad hoc build. The bundle reports 2.3.1 (103), its executable contains only arm64, and strict deep code-signature verification passed. The packaged ZIP is `.build/test-mac-2.3.1/UltimateLemmings-2.3.1-build103-arm64-test.zip` (SHA-256 `af1fa343f451dd104fe37bcf44a0fafc7c743dc5f4008e56c91fe96e5c05d515`). It is for manual testing, not a Sparkle update.

The first local build attempt stopped when a Swift asset tool tried to write a protected home-directory Clang cache. `Scripts/build-local-app.sh` now selects a project-local cache. The full-music packaging pass subsequently stopped at the sandboxed `sysctl` call in AAC compaction, so the app was completed with the supported `main` music scope. The asset bundler also reported stale Trolley certificates for this engine; those targets remain unverified in this app. A sandbox restriction prevented copying the completed app to Downloads, so the ZIP remains in the workspace for the owner to download. No app window or automated test was launched.

iOS, tvOS, sideloading and physical-device acceptance remain separate deliveries. The reported mobile and TV audio crackling has no recorded clean-device acceptance.
