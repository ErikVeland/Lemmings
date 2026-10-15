# TV branding assets

`main.swift` exports the TV asset catalogue from the original bitmap artwork.
It uses the aligned `GameMenuLogo` surfaces for the gold Ultimate badge and the
Lemmings mark. The walker is frame 2 of the right-facing walk animation in the
original Macintosh 2× artwork bank. It does not use enlarged DOS graphics.
The full mark sits below the walker. The planted foot meets the lettering beneath it.

The icon has five independent surfaces, listed front to back: Lemming, Ultimate,
Lemmings, Depth and Background. Ultimate, Lemmings and the walker each have their
own transparent image layer. The Depth layer belongs to the Lemmings mark;
the Ultimate badge carries its own extrusion. Foregrounds retain the pixel silhouettes.
Lit edges, a clipped surface highlight and an extruded logo provide depth.
tvOS supplies the focus movement and system lighting. The icon has no baked-in
tile, rounded mask or outer border.

Both icon sizes and their required scales share this composition. Static Top
Shelf artwork uses the same scene. Local flattened previews are written to
`.build/tv-icon/App Icon.png` and `.build/tv-icon/App Icon Large.png`.

Regenerate with `TV_EXPORT_ASSETS=1 zsh Scripts/check-tv-experience.sh`.
That script runs its native checks and exporter through the muted, offscreen
test runner. The export requires the Macintosh artwork in
`.build/mac-artwork/export/lemmings` and the gold badge in `Resources/MenuArtwork`.

The Swift exporter and Apple asset-catalogue compilation pass. Small and large
flattened renders have been inspected. Focus movement, dynamic system shine
and the appearance on a physical television still need device verification.
