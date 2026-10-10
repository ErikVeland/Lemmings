# Loading and transition latency

Measured on the local Apple Silicon development Mac on 25 September 2026.

## Causes fixed

- Level Select rebuilt every game's catalogue on each visit. Chronicles also constructed all 90 runtimes to check availability. Bundled identities and decoded metadata now stay in bounded process caches.
- Catalogue discovery starts after the first visible frame. A prepared catalogue opens directly. Classic Start also bypasses the loading page when its verified bundled artwork is already installed.
- Classic Start rebuilt the current campaign, picker and native menus. It now reuses the current bundled campaign.
- A forced checkpoint meant both “capture now” and “wait for disk.” Level starts and retries now capture immediately and use the serial background writer. Exit still waits for pending saves.
- Music recordings were decoded into a full-length PCM buffer on the main actor. They now stream, with two consecutive passes scheduled ahead for looping.
- Completed replay movies were copied and hashed on the main actor. Retention now holds an open source file and streams it to storage on a background task. Recorder cleanup can remove its temporary path without losing the open recording.

Bundled-resource caches apply only inside an application bundle. Imported game data and fan archives still receive fresh content checks. Content identities and replay checksums retain their existing formats.

## Local measurements

| Operation | Before | After |
| --- | ---: | ---: |
| Repeat Lemmings 2 catalogue | 60.0 ms | 0.1 ms |
| Repeat Lemmings 3 catalogue | 303.2 ms | below 0.1 ms |
| Prepared Classic browser | — | 55–71 ms |
| Prepared Classic Start | 418.3 ms before campaign/save fix | 13.6 ms |
| Repeat Classic retry | 24–52 ms before save fix | 10.7–11.2 ms |
| Dispatch retention of a 32 MB replay | — | 0.2 ms |

Catalogue baseline used optimized builds. The final Start/save checks used the integration executable with an optimized simulation library and unoptimized app code. These are local observations, not universal deadlines.

Cold work still exists: initial Classic content preparation measured 0.85–0.93 seconds, and the first Chronicles catalogue scan measured 0.48–0.69 seconds. The latter runs in the background during normal launch. New imports and changed archives must still be read and validated. No artificial delay was added, and the requested fresh-level countdown remains separate from loading.

## Validation

Run the focused latency and route checks:

```sh
TEST_SCOPE=loading-latency TEST_OPTIMIZE=1 zsh Scripts/run-app-integration-tests.sh
zsh Scripts/run-adaptive-dj-playback-tests.sh Sources/Music
zsh Scripts/run-fan-library-tests.sh
```

The latency harness checks that prepared browsing and Start avoid loading pages and retain the selected level. It also verifies byte-for-byte replay retention and its checksum after deleting the recorder's temporary source. The playback test exercises repeated streamed loops, suspend/resume and stale callbacks after stop. The rendered prepared browser was inspected at `.build/loading-browser.png`.

Streaming uses consecutive file scheduling provided by [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode).

The Hot Seat/recovery suite passed against an immutable resource bundle, including exact checkpoint restoration, legacy fan graphics upgrades, paused handovers and Escape saves. An initial run against `.build/local` failed while a separate build was updating that resource directory; use a completed app bundle through `LEMMINGS_TEST_APP` for repeatable checks.

Local test release: version 1.5, build 45. The Apple Development signature and ZIP integrity were verified. This local build is not notarised.
