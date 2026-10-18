# Ultimate Lemmings 2.0.6 for Macintosh

Build: 90
Release base: v2.0.4
iOS and iPadOS: 2.0.6 build 16 (TestFlight)
tvOS: 2.0.6 build 6 (TestFlight)

This release makes play smoother and adds light to the Macintosh arrows on HDR
displays. It also includes the unpublished 2.0.5 changes. These notes
summarise every 2.0 update, so players who skipped a patch can see all the
changes.

## Smoother play

The playfield, the minimap and the skill panel draw faster. With Macintosh
artwork on a P3 display, the panel draw time fell from 3.9 ms to 1.65 ms.
Classic and NeoLemmix redraws between ticks reuse their colour-matched pixels.

A level result no longer pauses the game when you have a long play history.
The career leaderboard and the result screen reuse earlier analysis. A new
level starts without a full records write on the main thread. Cloud progress
no longer rewrites its local file when nothing has changed.

Saved records, attempts and leaderboards keep the same format. Earlier saves
load without changes.

## Shining arrows

On an HDR display, Classic one-way arrows in Macintosh colour artwork catch the
light on their upper and left edges. The peak is 1.5 times SDR white, or less
when the screen has less headroom. SDR screens show the same pixels as before.

## Menu music

Most launches play the Amiga or the Macintosh title theme. One launch in eight
plays the title theme from another version of the game. To turn the menu theme
off, clear **Settings > Audio > Main menu: Play main theme**.

The tracker music no longer crackles at startup. Before, each launch and focus
event restarted the fade-in of the menu theme.

## Controller steps

Hold LT + LB / RB (Create + L1 / R1 on Apple TV) to scrub one tick at a time.
On a DualSense, slide a finger left or right on the touchpad to step back or
forward. Each step gives a light haptic tick. This works in Classic, The Tribes
and Chronicles on Mac, iPhone, iPad and Apple TV.

## Pointer

The Amiga cross now shows around gameplay in every pointer style, in Classic,
The Tribes and Chronicles. Menus keep the system arrow.

## Earlier 2.0.5 changes

- The death counter's skull no longer shrinks the gameplay status text.
- With Macintosh graphics, a lemming jumps into the centre of the drawn exit.
  Replays and saves do not change.
- In Chronicles, a Mole that touches steel follows the original game more
  closely. The bundled Chronicles routes keep their 2.0.4 results.

## Earlier 2.0 updates

- **2.0:** Original Macintosh 1-bit artwork with a matching monochrome
  gameplay panel. Journeys and sequence playlists resume the saved attempt.
  Classic can show an optional ghost solution. Seven added language packs use
  the original bitmap fonts.
- **2.0.2:** Hot Seat retries show earlier players' latest attempts as coloured
  ghosts. Retry actions and rewards use clearer grouping.
- **2.0.3:** Language buttons accept clicks across their full width.
- **2.0.4:** Worldwide Classic leaderboard entries identify the exact level. A
  revised journey no longer repeats its opening levels. Classic, The Tribes and
  NeoLemmix levels use less processing time.

## iPhone, iPad and Apple TV

These builds go to TestFlight external testers.

- **Hot Seat ghosts:** Each earlier player's latest turn shows as a translucent
  ghost behind the live lemmings, as on the Mac. Classic, Lemmings 2 and
  Lemmings 3 record their commands in the shared action format.
- **Home:** The Home footer reads Players, Progress and Playlists. Progress
  holds Records, Achievements, Worldwide and Play Insights.
- **Records:** A record card shows the level artwork, stars, statistics and
  achievements. Replay plays the newest kept action replay for a Classic
  record. Hints opens the level hint cards.
- **Pause:** Hint is the first pause action in Classic, Lemmings 2 and
  Lemmings 3. Pause > Hint > Ghost solution turns on the Classic ghost.
- **Macintosh music:** The apps now include the Macintosh song bank. Choose the
  Macintosh soundtrack in Settings.
- **Faster drawing:** The GPU now scales the playfield. One iPad-sized draw
  took 7–9 ms on the CPU before.
- **Apple TV Top Shelf:** The still shows at once. The clip follows when it is
  ready.
- **Cloud saves:** Testers on different accounts can share one library with a
  sync password. This is a testing aid and will be removed before the final
  release.

## Compatibility and known limits

The public app targets Apple silicon and Intel Macs running macOS 12.3 or later.
The slim fresh-install download contains essential music and offers optional
soundtrack libraries. Automatic updates retain the full soundtrack.

Classic and The Tribes retain their published Complete classifications.
Chronicles and NeoLemmix remain Beta.

Monochrome Macintosh art, Apple TV and CRT mode have no arrow glints. A lemming
that walks over a lit arrow edge also gets the added light. NeoLemmix has no
Hot Seat ghosts. Lemmings 2, Lemmings 3 and NeoLemmix have no Records playback.

The eight translated language packs remain AI-assisted drafts. Human language
review, physical controllers, VoiceOver, audible listening, minimum-OS and Intel
hardware, HDR appearance and live cross-device synchronisation retain their
recorded validation gaps. Camera panning and sustained frame timing on older
iPad, Apple TV and Intel Mac hardware need device validation.
