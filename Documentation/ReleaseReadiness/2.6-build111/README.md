# Ultimate Lemmings 2.6 build 111

Published on 26 November 2026 for macOS 12.3 or later on Apple silicon and Intel. [GitHub release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.6)

The release tag points to source commit `21a4af32c3e6c143842deddfd67f35a5ccfedd18`. The live update feed is on `main` at commit `d84e289366b10c5a1357aaf24c1305fad27fc1cc`.

App Store delivery uses the separate Ultimate Lemmix release branch.

## Downloads

| Download | SHA-256 | Apple notarisation |
| --- | --- | --- |
| Full update archive | `5cee1c01b420bb160b8b2c0fff8d8a99ba3e4d3105aa06f9a60b61b2e2131133` | Accepted and stapled. Submission `dcabb0e6-4dca-45fa-82dd-0410df168d99`. |
| Slim install archive | `0200d6303145939ec4e5855982ada52b2cb1de5b600f7bda5799f774ee24d353` | Accepted and stapled. Submission `f22cfeb6-3b04-4d1d-8080-a7595b9ee5bc`. |

Both archives passed ZIP integrity checks. Gatekeeper accepted the apps after extraction. The full archive is the download in the live feed.

## Sparkle updates

The live feed contains 33 entries. Its SHA-256 is `f45f3816ad05588cce8ec0dc56a1a2636d9d89f671ca615f4150720435ad274a`.

| Previous build | Delta SHA-256 |
| --- | --- |
| 110 | `06c54473cffc08361e6f62612fdd7f36eb649969f70d7ddb1cd3e027035ea9ff` |
| 109 | `5f918169c53cde64c816345a4ca6f3d83e67c2068a4aaa37792a4c365efe5780` |
| 106 | `55271b880d1983ff6c623b2bf9fca26cd29ff373faf8a7930aa4303dea07bcf2` |
| 105 | `0813369dfc1cc6ff47d72d3a501e0c2f8050683ba76d5f48d560e22fb5354bf8` |
| 104 | `76de404915c1de71e2e91bbaec54001cc3d44baedf8b8fdc0725f513b115a868` |

The feed passed signature, archive length and direct delta coverage checks. Applying the delta from build 110 produced the signed build 111 executable.

## Release checks

- Offscreen, muted checks passed for navigation, replay controls, frame pacing, Journey recovery and Hot Seat checkpoint ownership.
- All 38 Easy Puzzles resolved against their exact source data. The release gate verified 294 proofs, 315 rescue records and replay hashes.
- The engine proof fingerprint stayed the same. The broad integration suite and foreground launch audit were skipped under the release policy.
- Physical-device testing and hosted save-service acceptance remain open.
