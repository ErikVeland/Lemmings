# Ultimate Lemmings 2.7.1 build 113

Published on 26 November 2026 for macOS 12.3 or later on Apple silicon and Intel.
[GitHub release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.7.1)

The tag points to source commit `3a7ef75071d6a6f8f56326e8cafa24279d94cfaf`.
The update feed is on `main` at commit `fc1f71ebc713aad47baf85ff800c1094925ee863`.

## Downloads

| Download | SHA-256 | Apple notarisation |
| --- | --- | --- |
| Full update archive | `a9e7320e2cfff1111d912dd05359e1e6007089d096a14de349f040c08224b17b` | Accepted and stapled. Submission `f7484dc8-6826-4379-afb8-9e7bcabc21ef`. |
| Slim install archive | `14ac736527b2e896e8a921b236a2a7bfb98f9dac70f4d8ca04ee1c494c76ab29` | Accepted and stapled. Submission `d656293b-d7b9-4c9b-bee0-20819dfb20e5`. |

Both archives passed ZIP integrity checks. Gatekeeper accepted both extracted
apps. The published asset checksums match the local archives.

Each archive contains 11 loading-intro MODs
totalling 224,498 bytes. Each file matches the
[committed collection manifest](LoadingIntroModules.json).

## Sparkle updates

Live feed SHA-256 is `7ddefa40e2ecd90dc99d6c3ffbad08d5275d427aad55686c8d3e2fae76b8778c`.

| Previous build | Delta SHA-256 |
| --- | --- |
| 112 | `9410219073d3845ac0f192c46d105a60f4616c9f59c2f3fa62a7ebe770f9408a` |
| 111 | `12f92c070a267dd0804953b941e17e3856f9ce07522c6acefefe8c96edc27441` |
| 110 | `2974f56b6559bc54098d94f1bf461675de770413e3662f5175743cd768dd44da` |
| 109 | `7af4424c3999bf148f04c1e6477bfa196fe846e5dcfe0b393c52f4bfa74585c0` |
| 106 | `da8798232eacecc3014f934cfdf6c1376fec0b1d4c4e54ad10acd1c7af0ffeca` |

The feed passed signature, archive length and direct delta coverage checks.
Applying the delta from build 112 produced the signed build 113 executable.

## Release checks

The candidate changes Home and loading presentation. Simulation and replay
sources match build 112. Automated suites and launch checks were skipped
under the Mac release policy.
