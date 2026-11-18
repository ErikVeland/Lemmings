# Hosted action replay release

The ranking service update passed on 19 November 2026, Brisbane time. It now accepts the current app's action replay uploads.
No app engine source changed. No engine test suite ran.

| Item | Recorded value |
| --- | --- |
| Public service | `https://glasscode.academy/lemmings-api/rankings` |
| Candidate SHA-256 | `3ccaf3390ddf7dcdeede16754ea00cb5b673d2cb813c80217b36e4cb361cb443` |
| Previous SHA-256 | `d43acf483d0c15c72a0752c88d3432e3240de67771e6e9efa8cd3faf36849603` |
| Activation | 18 November 2026, 14:41 UTC |
| Cold backup | `/var/backups/lemmings-rankings/20261118T144150Z.9VSiFRA4` |
| Backup access | `700 root:root` |

The update replaced only `/opt/lemmings-rankings/server.py`. It preserved the service unit, Nginx configuration and live catalogue.
The service added the `runs.action_bytes` column without replacing existing records or replay files.
The wrapper stopped the service, copied its state and compared file hashes before activation.
It retained the private backup on the server. No user rows or private logs appeared in the release evidence.

All 20 focused server checks passed with local Python 3.14 and the server's Python 3.12 runtime.
They used temporary synthetic storage. Checks covered old-schema migration, credentials, scores, movies, action ownership, quotas, hashes and deletion.
Bonus command checks covered all four engines, all nine Lemmings 3 tools, invalid fields, integer bounds and duplicate grants.
Native replay reconstruction still checks level-specific NeoLemmix and Lemmings 2 skill-slot identity.

The public HTTPS check created one temporary player and run. It verified authenticated, repeated score submission and rejected an unauthenticated submission.
It uploaded a `bonusSkill` replay and downloaded identical bytes with the correct `X-Replay-SHA256` header.
Movie upload and download also passed. The check verified the assisted-board separation.
It then deleted its player, records and both replay files. Subsequent requests confirmed their absence.
Public health, active service status and unchanged configuration hashes passed after cleanup. No rollback was needed.

The live catalogue still contains 512 levels. The app catalogue contains 609 levels.
This update did not close that gap or recalculate targets from the newer catalogue.
Physical-device replay reconstruction, cross-device saves, Game Center and CloudKit acceptance remain separate checks.

For rollback, restore the saved program code and retain current state. Do not restore the old database after accepting new writes.
The old program cannot serve or delete new action replay files. A rollback therefore removes current action replay support.
Keep the cold backup private until an operator records its removal after acceptance.

The [JSON receipt](hosted-action-replay-release.json) records the non-secret checks and paths.
Detailed logs and reviewed deployment scripts are in `/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/service-deployment-review`.
