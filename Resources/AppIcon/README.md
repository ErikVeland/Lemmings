# Application icon

`AppIcon.png` is the source artwork, edited with the built-in image generation tool.
It uses an opaque square background that extends to every edge. There is no baked-in
border, bevel, shadow, or rounded tile, so the artwork does not create a second frame
inside the system icon shape.

`Scripts/build-app-icon.sh` compiles the source into the standard macOS icon sizes.

## Edit prompt

Use case: precise-object-edit
Asset type: full-bleed square application icon artwork for Ultimate Lemmings.
Input image: edit target, existing app icon.
Primary request: Remove the entire blue rounded-square frame, bevel, rim, outer shadow, and transparent outer margins. Replace them with a seamless extension of the existing midnight-blue/teal background all the way to all four square image edges and corners. The output must be an opaque square, with NO baked-in rounded corners, NO border, NO inset tile, NO outline around the canvas, and NO frame. The operating system will supply the icon mask.
Invariants: Preserve the same recognisable lime-green-haired Lemmings character, face, blue tunic, walking pose facing right, peach hands and feet, mossy ledge, sculpted 3D materials, lighting and colours. Keep the full hair and feet inside the canvas with comfortable breathing room. Extend the mossy terrain naturally to the bottom edge. Change only the surrounding frame/background treatment; keep the character appearance and overall composition as close to the input as possible. No text, badge, watermark, or mockup. Deliver one square 1024x1024 icon.
