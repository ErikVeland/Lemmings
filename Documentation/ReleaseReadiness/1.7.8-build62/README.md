# 1.7.8 build 62 release evidence

`checks.json` is the final result. `publication.json`, the final archive records,
Apple logs and `finalise.log` record distribution verification. `SHA256.json`
lists the size and digest of every other retained file in this directory.

`signed-candidates.json` is the historical pre-notarisation snapshot of the
submitted archives. The public downloads use the stapled final archives in
`slim-final-archive.json` and `standard-final-archive.json`.

The raw audit records a PercussionTests fixture failure. Its unchanged-binary
rerun and `audit-resolution.json` record the resolution. No failed result was
rewritten. See the candidate record for scope and validation limits.

The feed generator initially omitted its oldest item. Before publication, that
complete item was restored from the live baseline. `verify-feed.py` then passed:
all three previous enclosures and signatures remain unchanged. The publisher
also checks the preflight feed blob before updating main, so a concurrent feed
change causes it to stop.

The retained verifier scripts describe the release workspace procedure. Their
local paths refer to the preserved release directory and shipping archives.
