# 2.0 build 8 menu beta

The iOS prototype bypassed the Mac title screen, visual level browser and bitmap
page controls. This build uses the shared Mac logo, character sets, moss frame
and stone controls throughout its front end. The renderer and UIKit input
rectangles share one layout.

The title screen now shows Classic progress and a saved-run action when one is
available. Game Data owns folder import. Classic browsing includes a level
preview, rank and level navigation, horizontal swipes, totals and time. Briefing,
pause and win/loss pages use bitmap artwork and distinct primary actions.
Retry and next-level actions replace the game child without flashing the library.
Ready, restored and interrupted sessions still require explicit Start or Resume.
Selecting a skill pauses by default; the Settings toggle permits continuous
selection. Fast speed offers 2, 3, 5 and 10 times. Both settings and completed
Classic level indices persist locally. The privacy manifest declares this local
UserDefaults use and the archive validator requires its reason entry.

The headless renderer audit checks 66 states across iPad portrait/landscape,
iPhone portrait/landscape and narrow 320/568-point phone layouts. It covers home,
resume, preview browsing, briefing, pause, win, loss, Settings, Game Data, empty
content and the longest campaign title. All targets have at least 44-point
extents, stay inside scroll content and do not overlap. Disabled and gap hits
produce no action. Long titles and narrow action labels wrap. Rank and level
controls form separate pairs. Captures use the shared renderer; they are not
physical UIKit screenshots or real touch dispatch tests.

Home, level preview, briefing, results, Settings, pause and Game Data captures
were visually inspected on iPad and phone layouts. Narrow home and longest-title
captures were also inspected. The images remain in ignored build output because
they contain original game artwork. Renderer validation is attached here.
The frozen audit uses the filtered app artwork package. The snapshot retains
the original export manifest plus only the selected frames, so trying to load
that manifest directly requires omitted banks and fails. The packaging helper
filters those banks for the app. The corrected audit exercises this package
and the candidate's staged content. These preparation failures stay in the
headless logs; no foreground fallback was used.

Twenty mobile core tests and 67 release-tooling tests pass headlessly and muted.
The core checks include planning assignment and checkpoint retirement for all
three engine identities. The Classic content audit renders all 120 levels and
restores exact checkpoints after 50 ticks each. Eight offscreen Just Dig views
cover ready, running, panned and zoomed states in both iPad orientations.
The AppKit UI runner cannot validate UIKit, so no foreground fallback was used.
No test window, automatic game launch or audible test occurred.

Frozen production inputs are retained at `.build/ios-beta/SourceSnapshot-8`.
The verified signed candidate is `.build/ios-beta/2.0-8-menus`. Xcode beta 27.2
created its archive and development IPA. All 521 production inputs stayed
unchanged through export. The 309 packaged RGBA frames and filtered manifest
match the audited artwork package, archive and export exactly. Profile
membership includes GenErik iPad. Apple installation and its app query confirm
version 2.0, build 8 installed on GenErik iPad7,3 (iPadOS 17.7.11). The app was
not launched automatically. Physical UIKit acceptance remains pending.

IPA SHA-256: `0a9bd249e7ae1979816ed2fc8b2cb77fefb640b778757344c2c764c0c98e81ed`.
Retained arm64 dSYM UUID: `80F669D9-6CBF-325B-B6AA-AB66D347F9F7`.

This is a Classic menu beta, not full Mac feature parity or the full 2.0 launch.
The visible Lemmings 2 and Lemmings 3 rows remain disabled because their native
mobile libraries, renderers and campaign flows are not ported. Mac profiles,
Hot Seat, Journey, collections, records, replay/hint journeys, the full settings
and audio system, controller journeys, Duo layouts and accessibility acceptance
remain open. Result pages show counts and navigation; Mac celebration, trophy
and record presentation are not ported. The rank browser uses a focused preview,
not the Mac cover-flow card browser with its filters and favourites.

Manual iPad acceptance: open Ultimate Lemmings from the home screen. Check the
bitmap title screen, choose Lemmings, browse ranks and levels and select Play,
then Start. Verify terrain and lemmings. Pause, pan, pinch and assign a skill;
resume explicitly. Check Retry, Next Level and Library. Reopen a saved run from
the home screen. Rotate on each page and verify every visible button target.
Check both Settings states and retained progress after relaunch. Xcode Run
replaces the retained candidate with its source Debug build, whose default
bundle version is still 1. No TestFlight upload occurred.

Evidence: [menu renders and targets](menu-render-validation.json),
[frozen inputs](freeze-record.json), [core tests](mobile-core-tests.log),
[tooling tests](release-tooling-tests.log), [frozen menu audit](menu-audit.log), [signed archive](evidence.json),
[production input hashes](source-manifest.json), [packaged artwork](artwork-validation.json),
[120-level and bitmap checks](content-validation.json),
[verified installation](delivery.json), [installed app metadata](apps.json).
