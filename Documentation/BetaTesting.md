# Public testing

See the [release notes](ReleaseNotes.md) for the current Mac release and mobile
delivery state. Apple processing and Beta Review determine external tester
availability. Freeze one source commit for each public candidate. Earlier
records do not certify a new package.

## Newcomer and veteran playtests

This protocol supports the [2.1 foundation priorities](2.1Roadmap.md#priorities-and-acceptance)
and the [2.3 first-play milestone](Roadmap.md#23-first-play-and-the-next-day).
Recruit a small varied group of children with a guardian, adults unfamiliar with
games, returning players and veterans. Participation and observation need their
agreement. On 26 October 2026, the owner confirmed the first-session and next-day
playtests complete, with non-owner players observed on every supported device.
See the [acceptance record](ReleaseReadiness/2.3-human-acceptance-2026-10-26.md).

Use a fresh disposable profile and record the exact build, language, device and
input. Keep the player's ordinary saves separate. Let the first thirty minutes
run without unsolicited coaching. Use the existing Journey and introductory
levels. Experienced players may move on through the existing free Try later path.

Observe these tasks in order:

1. Start play from Home and identify the entrance and exit.
2. Select a skill and give it to a lemming facing the intended direction.
3. Describe what changed after the assignment.
4. Pause and use basic Zoom before earning any stars.
5. Make an ordinary mistake, recover and choose another idea.
6. Open help and identify whether it is level-specific or general coaching.
7. Request one further hint deliberately, then return to the same paused state.
8. Finish a level and identify the primary next action without interpreting career rewards.
9. Defer a difficult Journey lesson and find it again.
10. Quit, return the next day and resume the same run and owner.
11. Play one Hot Seat handover and wait for the next player's Ready.
12. Repeat the key input, pause, help and recovery tasks in L2 and L3, recording their current limits.

Record confusion, accidental assignments, recovery, voluntary retries, helpful
hints, unwanted spoilers and whether the player asks to continue. Completion time
and clears alone cannot measure discovery. Ask what the player noticed before
asking about stars, names, music or emotion. Do not treat visible frustration as
an instruction to reduce every puzzle's difficulty.

Compare optional character/effect presentation enabled and disabled, varying the
order across participants. Confirm that wants are understood as optional fiction,
that ordinary failure remains safe and funny, and that a valid one-star clear
feels successful. Human-review translated onboarding, hint availability and
failure/recovery copy. Retain anonymised findings and actionable changes in the
release evidence only with participant agreement.

Automated preparation stays offscreen and muted through Tools/UITestRunner/run.py.
Physical input, real screen-reader use, audible tone, HDR appearance, live sync and
sustained device loads need separate human/device records. This protocol does not
authorise foreground automated tests, audible tests, invitations or publication.

## Public beta boundary

Do not send a Game Center snapshot to an open tester group. It is development
signed for registered Macs and cannot pass notarisation. Use a Developer ID
signed, notarised archive for a public beta. Check the downloaded archive with
Gatekeeper on a clean Mac before inviting testers.

If the beta uses a direct download, keep it separate from the stable Sparkle
feed. State that updates are manual. Confirm the bundled game and soundtrack
assets are approved for public distribution. Record known preview limits in
the beta notes.

## Local builds

For a quick manual Mac build, use the current architecture and copy the app
to Downloads:

```sh
LEMMINGS_ARCHITECTURES="$(uname -m)" zsh Scripts/build-local-app.sh
ditto ".build/local/Ultimate Lemmings.app" "$HOME/Downloads/Ultimate Lemmings.app"
```

Skip automated tests, release audits, Intel compilation and notarisation for
this local build. See [development](Development.md) for the source-only workflow.

For a development-signed Game Center snapshot:

```sh
zsh Scripts/build-game-center-snapshot.sh
```

That snapshot requires a provisioning profile and runs only on registered Macs.
It is not notarised. Keep the tester roster and profile out of public downloads.
See [Game Center setup](GameCenterSetup.md).

## Public releases

Follow the [release schedule](ReleaseSchedule.md) and
[packaging procedure](../README.md#local-release-packaging). Mac delivery comes
first. Run affected engine checks only when engine behaviour changes. Keep
build, signature, notarisation, package and updater-feed checks for every release.
Record skipped checks explicitly.

`Scripts/package-beta.sh` is the historical beta packager. Its legacy notes
naming and full closure gate do not match the current release procedure.
Use `Scripts/build-and-notarise.sh` for current public packages.

A signed source build does not establish physical input, screen-reader use,
audible playback, live sync or sustained device performance. Record those
checks separately. Keep automated mechanical checks offscreen and muted through
`Tools/UITestRunner/run.py`. Foreground or audible checks require an explicit
request.

See [automatic updates](AutomaticUpdates.md) for feed and publication checks.
Keep credentials outside Git. Read [third-party notices](../THIRD_PARTY_NOTICES.md)
for content provenance and distribution scope.

## Report a problem

Include the build number, device, operating system, game, level, settings,
input method and reproduction steps in an
[issue](https://github.com/ErikVeland/Lemmings/issues/new).
Attach a screenshot or replay when it helps. Use copies of saved runs for
upgrade and recovery tests.
