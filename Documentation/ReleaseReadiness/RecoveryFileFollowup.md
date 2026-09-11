# Checkpoint file recovery follow-up

This isolated change follows beta 20. It is not included in the beta archives.

An oversized primary checkpoint previously failed its size check before the app
could try a valid backup. Recovery now validates the backup, preserves the primary
file without reading it into memory, and restores the backup atomically.

File size checks now discard cached URL metadata. Otherwise, a restored small
checkpoint could retain the old oversized file's cached size and fail again.

`Scripts/run-run-recovery-file-tests.sh` checks:

- Oversized primary recovery, preservation, repeated load and subsequent save.
- Invalid or missing backups without changing the primary.
- Unsupported document versions without replacing them with older backups.
- Stale writers, a busy file lock and cleared runs that must not return.

The headless tests passed using the unchanged beta 20 arm64 core library. No game
window, shared build output, installed saves or release archive was used for writes.
These checks do not cover physical power loss or installed-release migrations.
