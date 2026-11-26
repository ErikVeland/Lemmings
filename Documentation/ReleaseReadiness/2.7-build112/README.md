# Ultimate Lemmings 2.7 build 112

Published on 26 November 2026 for macOS 12.3 or later on Apple silicon and Intel.
[GitHub release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.7)

The tag points to source commit `31cf153c0128df1f8ade401ca62393dad319b750`.
The update feed is on `main` at commit `e3427b150a4cddaed15ccc0781b5e13fb834d5d9`.

## Downloads

| Download | SHA-256 | Apple notarisation |
| --- | --- | --- |
| Full update archive | `31db4f437b71c04675b0d0791ef491052839591f22edd85587c39f94e9d968c1` | Accepted and stapled. Submission `4e7bc3ae-1c37-4255-903b-63f436378ff0`. |
| Slim install archive | `12c6ed6ca546299441f9374df9e2ce4e408fae0bcd56030d4677af0eb2f685df` | Accepted and stapled. Submission `73e7ebdd-00e8-45b4-afd8-dc72a2650c4f`. |

Both archives passed ZIP integrity checks. Gatekeeper accepted both extracted
apps. The published asset checksums match the local archives.

## Sparkle updates

Live feed SHA-256 is `ee70aa5cba8a015ab8f4187459ae4e8f0c774a3cedf835d96dbf5556877cbab0`.

| Previous build | Delta SHA-256 |
| --- | --- |
| 105 | `6d357d5f378963b72a6845d011a4ed8fce08a7c85234ef96e2ed33869912d57a` |
| 106 | `6957dde8aab5aa4ed2d969091d494c05d37a0c0de51d6f2c9c4dffc6abce3b6d` |
| 109 | `db5410cf93e510f3fa8a1418b043e21c04e024fc6f03715f0bc833ce1859698f` |
| 110 | `a710e9ad40d61f7cd2c2263e34a06b3214d4b91924ed1e8d8cd448d9bdea419c` |
| 111 | `7f565185c68f1360e721940ff5b83ee14a6a6850e01be7741b88f0737b46cd05` |

The feed passed signature, archive length and direct delta coverage checks.
Applying the delta from build 111 produced the signed build 112 executable.

## Release checks

- The candidate changes presentation and camera preferences. The fixed-input
  simulation sources and replay behaviour are the same as in build 111.
- The source gate verified 294 existing proofs, 315 rescue records and replay hashes.
- Automated suites and launch checks were skipped under the Mac release policy.
- Physical-device testing and hosted save-service acceptance remain open.
