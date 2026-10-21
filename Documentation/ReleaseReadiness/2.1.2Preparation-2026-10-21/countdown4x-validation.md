# 4× countdown and corner controls validation

- Current source compiled for Mac arm64, including the current main.swift and all shared modules.
- Muted, offscreen native typography and gameplay-control suite passed through Tools/UITestRunner/run.py.
- Original 1× artwork is unchanged. Shared and native renderers agree at 2× and for the 4× numerals.
- All ten numeral contours differ from an enlarged 2× glyph. Fourfold bearings and advances are preserved.
- Transparent blue/green atlases, metrics, colour previews and 3/2/1 platform specimens exported.
- Countdown opacity inheritance and compact-HUD fallbacks passed.
- Classic, Lemmings 2 and Lemmings 3 checked at 640, 900 and 1600 points: 12-point top/right inset, 44-point targets, grouping, availability, shared fades, actions, popovers and focus.
- Both coordinate systems checked. Status readouts and the Lemmings 3 game-menu target avoid the icon row.
- Rendered Classic, Lemmings 2 and Lemmings 3 states and native-size countdown specimens inspected.
- Current iOS and tvOS source snapshots compiled through all shared UI modules and application entry points.
- No foreground windows or audible audio were used. Native NSWindow mouse delivery was skipped by the offscreen runner. Targets and direct actions passed. Physical mouse, touch and remote delivery remain manual checks.
- No installed app or user save was changed.

Font archive SHA-256: b6f6c246283f56451c0e4b42717bd2acc73d7a133d5faba28ab19916aa37a288
