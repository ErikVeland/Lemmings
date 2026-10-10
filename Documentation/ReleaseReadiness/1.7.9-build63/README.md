# 1.7.9 build 63 release evidence

`checks.json` records final results and validation limits. `publication.json`
records the public release and downloads. `SHA256.json` hashes every other
retained file. The Apple logs and final archive records identify the exact
notarised binaries.

Raw failed checks remain alongside their passing reruns. `test-resolutions.json`
explains the missing soundtrack fixtures and the replay byte-format mismatch.
No game code, stored replay, difficulty score or expected outcome was changed
to resolve them. The first standalone Golems helper compile used the wrong
Swift entry-point filename; the corrected compile and all subsequent logs remain.

Verifier scripts record this isolated checkout's procedure. Their absolute paths
refer to the preserved release directory. Native UI tests ran offscreen through
Tools/UITestRunner/run.py with audio muted.
