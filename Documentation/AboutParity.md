# Shared About pages

Mac, iPhone, iPad, Duo and Apple TV expose About, Version history and Contributors
using the game's bitmap controls. Mac uses stone tabs; mobile adapts navigation
to touch and remote input. The shared `AboutContent` loader, release index and
Markdown parser keep the content consistent. Back retains its initial focus,
and support actions follow the existing product and Store policy.

## Installed content and version history

`Scripts/bundle-about.py` bundles the current Ultimate Lemmings release notes
selected by `Resources/Info.plist`, together with heritage and fallback credits.
The `prepare_about` helper in `Tools/AlternativeAssets/prepare_lemmix_base.py`
reuses those credits and selects Ultimate Lemmix's own current notes from its
publication manifest. Version history works offline, including before a new
release is published. It does not depend on the update feed or combine the two
products' release histories.

Mobile reads these documents from the installed app bundle. Restoring game
assets cannot replace the app's credits or version history. Lix artwork and
soundtrack licences remain visible where applicable. The community forum action
opens the website where browsing is available, with a QR page on Apple TV and
as a fallback when a device cannot open the link.

## Contributor delivery

About displays bundled or previously cached contributor credits immediately.
A successful refresh replaces the cached list. A failed refresh preserves the
available credits and offers Retry. Leaving About cancels the request, and a late
response cannot replace a newer list or repaint a different destination.

Contributor request regressions use the About state with isolated preferences
and injected responses. They do not initialise the game library controller,
saved player profiles or hosted sync services. Native presentation checks remain
separate from these request and cache tests.

## Packaging and validation

The mobile source-check fixtures include the same bundled heritage, supporter
credits and edition-specific notes as their app. The focused packaging checks
verify exact copied bytes, keep About out of the widget bundle and reject
tampered contributor data. The legacy mobile source-check path also generates
the shared About documents before its source-only early return.

Native rendering, touch, remote and VoiceOver acceptance remain separate from
packaging and source validation. Current cross-platform status is recorded in
[Platform feature parity](PlatformFeatureParity.md).
