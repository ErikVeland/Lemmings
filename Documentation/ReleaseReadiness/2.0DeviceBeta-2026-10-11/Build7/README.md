# 2.0 build 7 playfield beta

Installed on GenErik iPad Pro 10.5-inch (iPad7,3), iPadOS 17.7.11.
Apple installation and its app query confirm version 2.0, bundle version 7.
Physical rendering acceptance awaits the owner's retest.

The owner reports Classic's library and controls but a black playfield on GenErik
with Just Dig. Apple's initial app query identifies version 2.0, build 1.
Xcode Debug installation had replaced the previously verified build 6 again.
The campaign now loads because Debug packaging includes the local Classic data.

The playfield now draws the engine's RGBA bitmap through Core Graphics in a
normal UIKit view. It retains the shared camera, nearest-pixel scaling, authored
start position, touch routing and accessibility name. It no longer depends on
Metal view scheduling, runtime shader compilation or drawable presentation.
Bitmap creation errors reach the existing game error flow. The previous Metal
setup silently discarded errors. Its shader compiled in a headless Mac GPU probe;
the exact cause of the physical iPad's black presentation was not established.

All 20 mobile core tests and 67 release-tooling tests pass headlessly and muted.
The new bitmap regression verifies colours, vertical orientation, nearest-pixel
scaling, letterboxing and camera-to-touch coordinates after pan, zoom and rotation.
All 120 Classic levels render and restore exact checkpoints after 50 ticks each.
Eight offscreen Just Dig playfield captures cover ready, running, panned and zoomed
states in portrait and landscape. Each contains visible coloured terrain. Ready
portrait, running landscape, zoomed portrait and panned landscape captures were
visually inspected. These are bitmap captures, not physical UIKit screenshots.
Captures stay under the candidate's ignored PlayfieldRenders folder.

Frozen source is retained at `.build/ios-beta/SourceSnapshot-7`. The candidate is
`.build/ios-beta/2.0-7-playfield`. The source snapshot includes selected Mac menu
artwork and the Classic campaign. All 309 exported RGBA artwork files exactly
match frozen inputs, and their filtered manifest and frame lengths pass checks.
All 518 frozen inputs remained unchanged through archive and export. It is not rewritten by later workspace edits.

No automatic game launch, test window or audible test occurred. Physical rendering,
real touch targets, rotation and sustained performance require the owner's next
manual check. The AppKit offscreen UI runner cannot validate UIKit, so no foreground
fallback was used. Saved runs and imported files are retained.

This remains the Classic device beta. L2/L3 mobile libraries and renderers, full
three-game release acceptance, audio, Hot Seat, controllers, Duo and accessibility
acceptance remain open. No TestFlight upload occurred.

Evidence: [verified installation](delivery.json), [installed app](apps.json),
[signed candidate](evidence.json), [frozen inputs](source-manifest.json),
[campaign and bitmap checks](content-validation.json), [menu artwork](artwork-validation.json),
[device before replacement](before-apps.json),
[core tests](mobile-core-tests.log), [tooling tests](release-tooling-tests.log),
[offscreen bitmap validation](offscreen-playfield-validation.json).

Retest directly from the iPad home screen: open Ultimate Lemmings, choose
Classic Levels, open 1. Just Dig, then select Start. Verify visible terrain and
lemmings, then pause, pan, pinch and assign a skill. Return to Library and Resume
to check the saved run. Xcode Run replaces the installed candidate with its Debug
product, whose default build number remains 1. That current source also uses the
bitmap playfield and local Classic data. The inspected signed candidate is build 7.

Signed IPA SHA-256: `ea30baa9f3b407f7ddbef052a8d4167336efce3d5963f9069802368321af33aa`.
The retained arm64 dSYM UUID is `C84921F3-7D48-31B2-8AD8-2204E2BFCA12`.
Archive, export, profile membership, metadata, icons, privacy declarations and
content checks pass. The raw archive/export logs stay with the ignored candidate.
