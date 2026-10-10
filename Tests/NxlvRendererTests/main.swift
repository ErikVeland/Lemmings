import CoreGraphics
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

enum TestFailure: Error, CustomStringConvertible {
  case assertion(String)

  var description: String {
    switch self {
    case .assertion(let message): message
    }
  }
}

struct TestColor: Equatable, CustomStringConvertible {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let alpha: UInt8

  var description: String { "RGBA(\(red),\(green),\(blue),\(alpha))" }

  static let clear = TestColor(red: 0, green: 0, blue: 0, alpha: 0)
  static let red = TestColor(red: 255, green: 0, blue: 0, alpha: 255)
  static let green = TestColor(red: 0, green: 255, blue: 0, alpha: 255)
  static let blue = TestColor(red: 0, green: 0, blue: 255, alpha: 255)
  static let yellow = TestColor(red: 255, green: 255, blue: 0, alpha: 255)
  static let cyan = TestColor(red: 0, green: 255, blue: 255, alpha: 255)
  static let magenta = TestColor(red: 255, green: 0, blue: 255, alpha: 255)
  static let white = TestColor(red: 255, green: 255, blue: 255, alpha: 255)
  static let black = TestColor(red: 0, green: 0, blue: 0, alpha: 255)
  static let orange = TestColor(red: 255, green: 128, blue: 0, alpha: 255)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  if !condition() { throw TestFailure.assertion(message) }
}

func unwrap<T>(_ value: T?, _ message: String) throws -> T {
  guard let value else { throw TestFailure.assertion(message) }
  return value
}

func write(_ text: String, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try Data(text.utf8).write(to: url)
}

func writePNG(
  width: Int,
  height: Int,
  pixels: [TestColor],
  to url: URL
) throws {
  try expect(pixels.count == width * height, "The PNG fixture has the wrong pixel count.")
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  let bytes = pixels.flatMap { [$0.red, $0.green, $0.blue, $0.alpha] }
  guard let provider = CGDataProvider(data: Data(bytes) as CFData),
    let image = CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        .union(.byteOrder32Big),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    ),
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil
    )
  else {
    throw TestFailure.assertion("The PNG fixture encoder could not start.")
  }
  CGImageDestinationAddImage(destination, image, nil)
  try expect(CGImageDestinationFinalize(destination), "The PNG fixture encoder failed.")
}

func pixel(_ rendered: NxlvRenderedLevel, x: Int, y: Int) -> TestColor {
  let offset = (y * rendered.width + x) * 4
  return TestColor(
    red: rendered.rgba[offset],
    green: rendered.rgba[offset + 1],
    blue: rendered.rgba[offset + 2],
    alpha: rendered.rgba[offset + 3]
  )
}

func pixel(_ rgba: [UInt8], width: Int, x: Int, y: Int) -> TestColor {
  let offset = (y * width + x) * 4
  return TestColor(
    red: rgba[offset],
    green: rgba[offset + 1],
    blue: rgba[offset + 2],
    alpha: rgba[offset + 3]
  )
}

func mask(_ values: [UInt8], width: Int, x: Int, y: Int) -> UInt8 {
  values[y * width + x]
}

func has(
  _ code: NxlvRenderDiagnosticCode,
  in result: NxlvRenderResult
) -> Bool {
  result.diagnostics.contains { $0.code == code }
}

func level(_ text: String) throws -> NxlvLevel {
  try unwrap(NxlvLevel(text: text), "The NXLV fixture did not parse.")
}

func render(
  _ level: NxlvLevel,
  styles: URL,
  renderer: NxlvRenderer = NxlvRenderer()
) throws -> NxlvRenderResult {
  let resolution = NxlvStyleResolver(stylesRootURL: styles).resolve(level: level)
  return renderer.render(level: level, resolution: resolution)
}

func makeTerrainFixtures(_ styles: URL) throws {
  try write(
    """
    LEMMINGS default
    $COLORS
      MASK xA1B2C3
    $END
    """,
    to: styles.appendingPathComponent("test/theme.nxtm")
  )
  let terrain = styles.appendingPathComponent("test/terrain", isDirectory: true)
  try writePNG(
    width: 2,
    height: 3,
    pixels: [.red, .green, .blue, .yellow, .cyan, .magenta],
    to: terrain.appendingPathComponent("asym.png")
  )
  try writePNG(
    width: 3,
    height: 2,
    pixels: Array(repeating: .red, count: 6),
    to: terrain.appendingPathComponent("red.png")
  )
  try writePNG(
    width: 2,
    height: 2,
    pixels: Array(repeating: .green, count: 4),
    to: terrain.appendingPathComponent("green.png")
  )
  try writePNG(
    width: 1,
    height: 1,
    pixels: [.blue],
    to: terrain.appendingPathComponent("blue.png")
  )
  try writePNG(
    width: 2,
    height: 2,
    pixels: Array(repeating: .white, count: 4),
    to: terrain.appendingPathComponent("steel.png")
  )
  try write("STEEL\n", to: terrain.appendingPathComponent("steel.nxmt"))
  try writePNG(
    width: 1,
    height: 1,
    pixels: [.black],
    to: terrain.appendingPathComponent("eraser.png")
  )
  try writePNG(
    width: 2,
    height: 1,
    pixels: [.white, .white],
    to: terrain.appendingPathComponent("eligible.png")
  )
  try writePNG(
    width: 2,
    height: 1,
    pixels: [
      TestColor(red: 255, green: 0, blue: 0, alpha: 0),
      TestColor(red: 0, green: 255, blue: 0, alpha: 1),
    ],
    to: terrain.appendingPathComponent("alpha.png")
  )
  try writePNG(
    width: 3,
    height: 3,
    pixels: [
      .red, .green, .blue,
      .yellow, .white, .cyan,
      .magenta, .orange, .black,
    ],
    to: terrain.appendingPathComponent("nine.png")
  )
  try write(
    """
    RESIZE_BOTH
    DEFAULT_WIDTH 5
    DEFAULT_HEIGHT 4
    NINE_SLICE_TOP 1
    NINE_SLICE_LEFT 1
    NINE_SLICE_RIGHT 1
    NINE_SLICE_BOTTOM 1
    """,
    to: terrain.appendingPathComponent("nine.nxmt")
  )
}

func makeObjectFixtures(_ styles: URL) throws {
  let objects = styles.appendingPathComponent("test/objects", isDirectory: true)
  try writePNG(
    width: 2,
    height: 2,
    pixels: Array(repeating: .orange, count: 4),
    to: objects.appendingPathComponent("arrow.png")
  )
  try write(
    """
    EFFECT ONEWAYRIGHT
    TRIGGER_X 0
    TRIGGER_Y 0
    TRIGGER_WIDTH 2
    TRIGGER_HEIGHT 2
    $PRIMARY_ANIMATION
      FRAMES 1
    $END
    """,
    to: objects.appendingPathComponent("arrow.nxmo")
  )
  try writePNG(
    width: 1,
    height: 2,
    pixels: [.magenta, .cyan],
    to: objects.appendingPathComponent("decor.png")
  )
  try write(
    """
    $PRIMARY_ANIMATION
      FRAMES 2
      INITIAL_FRAME 1
    $END
    """,
    to: objects.appendingPathComponent("decor.nxmo")
  )
  try writePNG(
    width: 1,
    height: 5,
    pixels: [.red, .green, .blue, .yellow, .magenta],
    to: objects.appendingPathComponent("remainder.png")
  )
  try write(
    """
    $PRIMARY_ANIMATION
      FRAMES 2
      INITIAL_FRAME 1
    $END
    """,
    to: objects.appendingPathComponent("remainder.nxmo")
  )
  try writePNG(
    width: 2,
    height: 1,
    pixels: [.cyan, .cyan],
    to: objects.appendingPathComponent("paint.png")
  )
  try write(
    """
    EFFECT PAINT
    $PRIMARY_ANIMATION
      FRAMES 1
    $END
    """,
    to: objects.appendingPathComponent("paint.nxmo")
  )
  try writePNG(
    width: 2,
    height: 2,
    pixels: Array(repeating: .green, count: 4),
    to: objects.appendingPathComponent("overflow_exit.png")
  )
  try write(
    """
    EFFECT EXIT
    TRIGGER_X 0
    TRIGGER_Y 1
    TRIGGER_WIDTH 2
    TRIGGER_HEIGHT 2
    $PRIMARY_ANIMATION
      FRAMES 1
    $END
    """,
    to: objects.appendingPathComponent("overflow_exit.nxmo")
  )
  for (name, effect) in [("button", "UNLOCKBUTTON"), ("locked", "LOCKEDEXIT")] {
    try writePNG(
      width: 1,
      height: 4,
      pixels: [.red, .green, .blue, .yellow],
      to: objects.appendingPathComponent("\(name).png")
    )
    try write(
      """
      EFFECT \(effect)
      TRIGGER_X 0
      TRIGGER_Y 0
      TRIGGER_WIDTH 1
      TRIGGER_HEIGHT 1
      $PRIMARY_ANIMATION
        FRAMES 4
      $END
      """,
      to: objects.appendingPathComponent("\(name).nxmo")
    )
  }
  try writePNG(
    width: 1,
    height: 4,
    pixels: [.red, .green, .blue, .yellow],
    to: objects.appendingPathComponent("live_trap.png")
  )
  try write(
    """
    EFFECT TRAP
    TRIGGER_X 0
    TRIGGER_Y 0
    TRIGGER_WIDTH 1
    TRIGGER_HEIGHT 1
    $PRIMARY_ANIMATION
      FRAMES 4
    $END
    """,
    to: objects.appendingPathComponent("live_trap.nxmo")
  )
  try writePNG(
    width: 1,
    height: 4,
    pixels: [.red, .green, .blue, .yellow],
    to: objects.appendingPathComponent("live_exit.png")
  )
  try write(
    """
    EFFECT EXIT
    TRIGGER_X 0
    TRIGGER_Y 0
    TRIGGER_WIDTH 1
    TRIGGER_HEIGHT 1
    $PRIMARY_ANIMATION
      FRAMES 4
    $END
    """,
    to: objects.appendingPathComponent("live_exit.nxmo")
  )
  try writePNG(
    width: 1,
    height: 4,
    pixels: [.red, .green, .blue, .yellow],
    to: objects.appendingPathComponent("live_entrance.png")
  )
  try write(
    """
    EFFECT ENTRANCE
    TRIGGER_X 0
    TRIGGER_Y 0
    $PRIMARY_ANIMATION
      FRAMES 4
    $END
    """,
    to: objects.appendingPathComponent("live_entrance.nxmo")
  )
  try writePNG(
    width: 1,
    height: 2,
    pixels: [.red, .green],
    to: objects.appendingPathComponent("live_splitter.png")
  )
  try write(
    """
    EFFECT SPLITTER
    TRIGGER_X 0
    TRIGGER_Y 0
    TRIGGER_WIDTH 1
    TRIGGER_HEIGHT 1
    $PRIMARY_ANIMATION
      FRAMES 2
    $END
    """,
    to: objects.appendingPathComponent("live_splitter.nxmo")
  )
  try writePNG(
    width: 1,
    height: 2,
    pixels: [.red, .green],
    to: objects.appendingPathComponent("moving_background.png")
  )
  try write(
    """
    EFFECT BACKGROUND
    $PRIMARY_ANIMATION
      FRAMES 2
    $END
    """,
    to: objects.appendingPathComponent("moving_background.nxmo")
  )
  try writePNG(
    width: 1,
    height: 1,
    pixels: [.red],
    to: objects.appendingPathComponent("secondary.png")
  )
  try writePNG(
    width: 1,
    height: 2,
    pixels: [.green, .blue],
    to: objects.appendingPathComponent("secondary_glow.png")
  )
  try writePNG(
    width: 1,
    height: 2,
    pixels: [.cyan, .magenta],
    to: objects.appendingPathComponent("secondary_pause.png")
  )
  try writePNG(
    width: 1,
    height: 2,
    pixels: [.yellow, .orange],
    to: objects.appendingPathComponent("secondary_loop.png")
  )
  try write(
    """
    EFFECT EXIT
    TRIGGER_X 0
    TRIGGER_Y 0
    TRIGGER_WIDTH 1
    TRIGGER_HEIGHT 1
    $PRIMARY_ANIMATION
      FRAMES 1
    $END
    $ANIMATION
      NAME glow
      FRAMES 2
      OFFSET_X 1
      Z_INDEX 2
    $END
    $ANIMATION
      NAME pause
      FRAMES 2
      OFFSET_X 2
      INITIAL_FRAME 1
      STATE PAUSE
      Z_INDEX 2
    $END
    $ANIMATION
      NAME loop
      FRAMES 2
      OFFSET_X 3
      INITIAL_FRAME 1
      STATE LOOPTOZERO
      Z_INDEX 2
    $END
    """,
    to: objects.appendingPathComponent("secondary.nxmo")
  )
  try writePNG(
    width: 1,
    height: 1,
    pixels: [.red],
    to: objects.appendingPathComponent("triggered_secondary.png")
  )
  try writePNG(
    width: 1,
    height: 1,
    pixels: [.green],
    to: objects.appendingPathComponent("triggered_secondary_busy.png")
  )
  try write(
    """
    EFFECT TRAP
    TRIGGER_X 0
    TRIGGER_Y 0
    TRIGGER_WIDTH 1
    TRIGGER_HEIGHT 1
    $PRIMARY_ANIMATION
      FRAMES 1
    $END
    $ANIMATION
      NAME busy
      FRAMES 1
      OFFSET_X 1
      HIDE
      $TRIGGER
        CONDITION BUSY
      $END
    $END
    """,
    to: objects.appendingPathComponent("triggered_secondary.nxmo")
  )
  try writePNG(
    width: 2,
    height: 1,
    pixels: [.red, .red],
    to: objects.appendingPathComponent("no_overwrite_layers.png")
  )
  try writePNG(
    width: 2,
    height: 1,
    pixels: [.green, .green],
    to: objects.appendingPathComponent("no_overwrite_layers_top.png")
  )
  try write(
    """
    EFFECT DECORATION
    $PRIMARY_ANIMATION
      FRAMES 1
      Z_INDEX 1
    $END
    $ANIMATION
      NAME top
      FRAMES 1
      Z_INDEX 2
    $END
    """,
    to: objects.appendingPathComponent("no_overwrite_layers.nxmo")
  )
}

func testTriggerOutsideGraphic(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Trigger outside graphic
    WIDTH 8
    HEIGHT 8
    $GADGET
      STYLE test
      PIECE overflow_exit
      X 3
      Y 2
    $END

    $GADGET
      STYLE test
      PIECE overflow_exit
      X 0
      Y 4
      FLIP_HORIZONTAL
    $END
    """)
  let output = try unwrap(
    render(fixture, styles: styles).renderedLevel,
    "The trigger-overflow fixture did not render."
  )
  let gadget = try unwrap(output.gadgets.first, "The trigger-overflow gadget was omitted.")
  try expect(gadget.triggerX == 3 && gadget.triggerY == 3,
             "The trigger-overflow origin changed.")
  try expect(gadget.triggerWidth == 2 && gadget.triggerHeight == 2,
             "A trigger row outside the graphic was clipped.")
  let flipped = try unwrap(output.gadgets.dropFirst().first, "The flipped trigger gadget was omitted.")
  try expect(flipped.triggerX == 0 && flipped.triggerY == 5,
             "A visual flip incorrectly mirrored the trigger rectangle.")
}

func testPaintClipsToTerrain(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Paint clipping
    WIDTH 3
    HEIGHT 1
    $TERRAIN
      STYLE test
      PIECE blue
      X 1
      Y 0
    $END
    $GADGET
      STYLE test
      PIECE paint
      X 0
      Y 0
    $END
    """)
  let output = try unwrap(
    render(fixture, styles: styles).renderedLevel, "The paint fixture did not render."
  )
  try expect(pixel(output, x: 0, y: 0) == .clear,
             "Paint appeared without terrain beneath it.")
  try expect(pixel(output, x: 1, y: 0) == .cyan,
             "Paint did not cover the terrain pixel.")
}

func testTransforms(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Transform
    WIDTH 6
    HEIGHT 5
    $TERRAIN
      STYLE test
      PIECE asym
      X 1
      Y 1
      ROTATE
      FLIP_HORIZONTAL
      FLIP_VERTICAL
    $END
    """)
  let result = try render(fixture, styles: styles)
  let output = try unwrap(result.renderedLevel, "The transform fixture did not render.")
  let expected: [[TestColor]] = [
    [.green, .yellow, .magenta],
    [.red, .blue, .cyan],
  ]
  for y in 0..<2 {
    for x in 0..<3 {
      try expect(
        pixel(output, x: x + 1, y: y + 1) == expected[y][x],
        "Rotate-then-flip produced the wrong pixel at \(x),\(y): \(pixel(output, x: x + 1, y: y + 1))."
      )
    }
  }
}

func testTerrainCompositionAndOneWay(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Terrain composition
    WIDTH 6
    HEIGHT 4
    $TERRAIN
      STYLE test
      PIECE red
      X -1
      Y 0
    $END
    $TERRAIN
      STYLE test
      PIECE steel
      X 2
      Y 0
    $END
    $TERRAIN
      STYLE test
      PIECE green
      X 3
      Y 0
      NO_OVERWRITE
    $END
    $TERRAIN
      STYLE test
      PIECE blue
      X 2
      Y 0
    $END
    $TERRAIN
      STYLE test
      PIECE eraser
      X 3
      Y 0
      ERASE
    $END
    $TERRAIN
      STYLE test
      PIECE eligible
      X 1
      Y 2
      ONE_WAY
    $END
    $TERRAIN
      STYLE test
      PIECE eligible
      X 4
      Y 2
      ONE_WAY
    $END
    $TERRAIN
      STYLE test
      PIECE alpha
      X 0
      Y 3
    $END
    $GADGET
      STYLE test
      PIECE arrow
      X 1
      Y 2
    $END
    $GADGET
      STYLE test
      PIECE arrow
      X 4
      Y 2
      ROTATE
      FLIP_VERTICAL
    $END
    """)
  let result = try render(fixture, styles: styles)
  let output = try unwrap(result.renderedLevel, "The terrain fixture did not render.")

  try expect(pixel(output, x: 0, y: 0) == .red, "Negative-coordinate clipping failed.")
  try expect(pixel(output, x: 2, y: 0) == .blue, "A normal piece did not replace steel.")
  try expect(mask(output.steelMask, width: 6, x: 2, y: 0) == 0, "Overwritten steel remained steel.")
  try expect(pixel(output, x: 3, y: 0) == .clear, "The eraser did not clear terrain.")
  try expect(
    mask(output.solidMask, width: 6, x: 3, y: 0) == 0, "The eraser did not clear solidity.")
  try expect(pixel(output, x: 4, y: 0) == .green, "NO_OVERWRITE did not fill an empty pixel.")
  try expect(mask(output.steelMask, width: 6, x: 2, y: 1) == 1, "Visible steel lost its mask.")
  try expect(pixel(output, x: 3, y: 1) == .white, "NO_OVERWRITE replaced existing steel.")
  try expect(
    mask(output.oneWayEligibleMask, width: 6, x: 1, y: 2) == 1,
    "ONE_WAY terrain was not marked eligible."
  )
  try expect(
    mask(output.oneWayMask, width: 6, x: 1, y: 2) == NxlvOneWayDirection.right.rawValue,
    "The directional one-way trigger was not projected onto terrain."
  )
  try expect(pixel(output, x: 1, y: 2) == .orange, "The one-way gadget was not composed.")
  try expect(
    mask(output.oneWayMask, width: 6, x: 4, y: 2) == NxlvOneWayDirection.up.rawValue,
    "The one-way direction did not follow rotate-then-flip transforms."
  )
  try expect(mask(output.solidMask, width: 6, x: 0, y: 3) == 0, "Alpha 0 became solid.")
  try expect(mask(output.solidMask, width: 6, x: 1, y: 3) == 1, "Nonzero alpha was not solid.")
  try expect(mask(output.terrainOpaqueMask, width: 6, x: 1, y: 3) == 0,
             "Partially transparent terrain became visually opaque.")
}

func testGroups(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Groups
    WIDTH 7
    HEIGHT 3
    $TERRAINGROUP
      NAME inner
      $TERRAIN
        STYLE test
        PIECE red
        X -1
        Y 0
      $END
      $TERRAIN
        STYLE test
        PIECE eraser
        X 0
        Y 0
        ERASE
      $END
    $END
    $TERRAINGROUP
      NAME outer
      $TERRAIN
        STYLE *GROUP
        PIECE inner
        X 0
        Y 0
      $END
      $TERRAIN
        STYLE test
        PIECE green
        X 1
        Y 0
        NO_OVERWRITE
      $END
    $END
    $TERRAIN
      STYLE *GROUP
      PIECE outer
      X 2
      Y 1
      FLIP_HORIZONTAL
      ONE_WAY
    $END
    """)
  let result = try render(fixture, styles: styles)
  let output = try unwrap(result.renderedLevel, "The terrain-group fixture did not render.")
  try expect(pixel(output, x: 3, y: 1) == .green, "Nested group fill or flip failed.")
  try expect(pixel(output, x: 4, y: 1) == .red, "Nested group origin normalization failed.")
  try expect(
    mask(output.oneWayEligibleMask, width: 7, x: 2, y: 1) == 1,
    "The outer group ONE_WAY flag was not applied."
  )

  let croppedGroup = try level(
    """
    TITLE Cropped group
    WIDTH 5
    HEIGHT 2
    $TERRAINGROUP
      NAME cropped
      $TERRAIN
        STYLE test
        PIECE red
        X 10
        Y 10
      $END
      $TERRAIN
        STYLE test
        PIECE eraser
        X 10
        Y 10
        ERASE
      $END
      $TERRAIN
        STYLE test
        PIECE eraser
        X 10
        Y 11
        ERASE
      $END
    $END
    $TERRAIN
      STYLE *GROUP
      PIECE cropped
      X 1
      Y 0
    $END
    """)
  let croppedOutput = try unwrap(
    render(croppedGroup, styles: styles).renderedLevel,
    "The cropped terrain-group fixture did not render."
  )
  try expect(pixel(croppedOutput, x: 1, y: 0) == .red,
             "The composite group retained its erased transparent margin.")
  try expect(pixel(croppedOutput, x: 0, y: 0) == .clear,
             "The cropped composite moved before its placement coordinate.")

  let forward = try level(
    """
    TITLE Forward group
    WIDTH 4
    HEIGHT 2
    $TERRAINGROUP
      NAME outer
      $TERRAIN
        STYLE *GROUP
        PIECE later
        X 0
        Y 0
      $END
    $END
    $TERRAINGROUP
      NAME later
      $TERRAIN
        STYLE test
        PIECE blue
        X 0
        Y 0
      $END
    $END
    $TERRAIN
      STYLE *GROUP
      PIECE outer
      X 0
      Y 0
    $END
    """)
  let forwardResult = try render(forward, styles: styles)
  try expect(
    has(.forwardTerrainGroupReference, in: forwardResult),
    "A forward terrain-group reference was not rejected."
  )

  let mixed = try level(
    """
    TITLE Mixed group
    WIDTH 4
    HEIGHT 2
    $TERRAINGROUP
      NAME invalid
      $TERRAIN
        STYLE test
        PIECE steel
        X 0
        Y 0
      $END
      $TERRAIN
        STYLE test
        PIECE blue
        X 1
        Y 0
      $END
    $END
    $TERRAIN
      STYLE *GROUP
      PIECE invalid
      X 0
      Y 0
    $END
    """)
  let mixedResult = try render(mixed, styles: styles)
  try expect(
    has(.mixedTerrainGroupMaterial, in: mixedResult),
    "A terrain group mixed steel and non-steel pieces without an error."
  )
}

func testNineSliceAndDefaults(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Nine slice
    WIDTH 10
    HEIGHT 6
    $TERRAIN
      STYLE test
      PIECE nine
      X 0
      Y 0
    $END
    $TERRAIN
      STYLE test
      PIECE nine
      X 6
      Y 1
      WIDTH 4
      HEIGHT 5
    $END
    $TERRAIN
      STYLE test
      PIECE nine
      X 9
      Y 0
      WIDTH 1
      HEIGHT 1
    $END
    """)
  let result = try render(fixture, styles: styles)
  let output = try unwrap(result.renderedLevel, "The nine-slice fixture did not render.")

  try expect(pixel(output, x: 0, y: 0) == .red, "The top-left margin changed.")
  try expect(pixel(output, x: 4, y: 0) == .blue, "The top-right margin changed.")
  try expect(pixel(output, x: 0, y: 3) == .magenta, "The bottom-left margin changed.")
  try expect(pixel(output, x: 4, y: 3) == .black, "The bottom-right margin changed.")
  try expect(pixel(output, x: 3, y: 2) == .white, "The nine-slice center did not tile.")
  try expect(pixel(output, x: 9, y: 5) == .black, "Explicit resize or clipping failed.")
  try expect(pixel(output, x: 9, y: 0) == .black, "Small nine-slice margins were not trimmed like CE.")
}

func testRemainderAnimationStrip(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Animation remainder
    WIDTH 2
    HEIGHT 2
    $GADGET
      STYLE test
      PIECE remainder
      X 0
      Y 0
    $END
    """)
  let result = try render(fixture, styles: styles)
  let output = try unwrap(result.renderedLevel, "The remainder animation did not render.")
  try expect(pixel(output, x: 0, y: 0) == .blue, "CE integer frame division was not used.")
  try expect(
    has(.invalidAnimationStrip, in: result),
    "Remainder pixels in an animation strip were not reported."
  )
  try expect(!result.hasErrors, "A CE-compatible remainder strip was rejected.")
}

func testBackgroundAndPrimaryGadget(_ styles: URL) throws {
  let backgrounds = styles.appendingPathComponent("test/backgrounds", isDirectory: true)
  try writePNG(
    width: 2,
    height: 2,
    pixels: [.red, .green, .blue, .yellow],
    to: backgrounds.appendingPathComponent("checker.png")
  )
  let fixture = try level(
    """
    TITLE Static layers
    WIDTH 5
    HEIGHT 3
    BACKGROUND test:checker
    $GADGET
      STYLE test
      PIECE decor
      X 3
      Y 1
    $END
    """)
  let result = try render(fixture, styles: styles)
  let output = try unwrap(result.renderedLevel, "The static-layer fixture did not render.")
  try expect(pixel(output, x: 4, y: 2) == .red, "The background did not tile from the origin.")
  try expect(pixel(output, x: 3, y: 1) == .cyan, "The selected primary gadget frame is wrong.")
  try expect(output.gadgets.count == 1, "The rendered gadget descriptor is missing.")
}

func testPNGAndPathLimits(_ fixture: URL) throws {
  let styles = fixture.appendingPathComponent("limit-styles", isDirectory: true)
  let terrain = styles.appendingPathComponent("limits/terrain", isDirectory: true)
  try FileManager.default.createDirectory(at: terrain, withIntermediateDirectories: true)
  try Data([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0]).write(
    to: terrain.appendingPathComponent("bad.png")
  )
  try writePNG(
    width: 5,
    height: 1,
    pixels: Array(repeating: .red, count: 5),
    to: terrain.appendingPathComponent("wide.png")
  )
  try writePNG(
    width: 4,
    height: 4,
    pixels: Array(repeating: .blue, count: 16),
    to: terrain.appendingPathComponent("square.png")
  )
  try writePNG(
    width: 1,
    height: 1,
    pixels: [.green],
    to: terrain.appendingPathComponent("tiny.png")
  )
  let fixtureLevel = try level(
    """
    TITLE Limits
    WIDTH 8
    HEIGHT 2
    $TERRAIN
      STYLE limits
      PIECE bad
      X 0
      Y 0
    $END
    $TERRAIN
      STYLE limits
      PIECE wide
      X 0
      Y 1
    $END
    $TERRAIN
      STYLE limits
      PIECE square
      X 4
      Y 0
    $END
    """)
  let limits = NxlvRendererLimits(
    maximumLevelDimension: 16,
    maximumLevelPixels: 32,
    maximumGraphicDimension: 4,
    maximumGraphicPixels: 8,
    maximumGraphicFileBytes: 1_048_576,
    maximumTerrainGroupPixels: 16
  )
  let result = try render(fixtureLevel, styles: styles, renderer: NxlvRenderer(limits: limits))
  try expect(
    has(.malformedPNG, in: result),
    "A malformed PNG was not rejected. Diagnostics: \(result.diagnostics.map(\.code))"
  )
  try expect(
    has(.graphicDimensionLimitExceeded, in: result),
    "An oversized PNG dimension was not rejected before decode."
  )
  try expect(has(.graphicPixelLimitExceeded, in: result), "The PNG pixel limit was not enforced.")

  let byteLimited = try render(
    fixtureLevel,
    styles: styles,
    renderer: NxlvRenderer(
      limits: NxlvRendererLimits(
        maximumLevelDimension: 16,
        maximumLevelPixels: 32,
        maximumGraphicDimension: 16,
        maximumGraphicPixels: 64,
        maximumGraphicFileBytes: 8,
        maximumTerrainGroupPixels: 16
      ))
  )
  try expect(
    has(.graphicFileTooLarge, in: byteLimited), "The PNG file-byte limit was not enforced.")

  let overflowLevel = try level(
    """
    TITLE Coordinate overflow
    WIDTH 2
    HEIGHT 2
    $TERRAIN
      STYLE limits
      PIECE tiny
      X \(Int.max)
      Y 0
    $END
    """)
  let overflowResult = try render(overflowLevel, styles: styles)
  try expect(has(.invalidPlacement, in: overflowResult), "Coordinate overflow was not diagnosed.")

  let outside = fixture.appendingPathComponent("outside.png")
  try writePNG(width: 1, height: 1, pixels: [.red], to: outside)
  let unsafeLevel = try level(
    """
    TITLE Unsafe path
    WIDTH 2
    HEIGHT 2
    $TERRAIN
      STYLE limits
      PIECE escape
      X 0
      Y 0
    $END
    """)
  let reference = NxlvStyleAssetReference(kind: .terrain, style: "limits", piece: "escape")
  let unsafeAsset = NxlvResolvedStyleAsset(
    reference: reference,
    styleDirectoryURL: styles.appendingPathComponent("limits"),
    graphicURLs: [outside],
    metadataURL: nil,
    terrainMetadata: NxlvTerrainMetadata(
      isSteel: false,
      isDeprecated: false,
      resizeAxes: [],
      nineSlice: NxlvNineSliceMargins(top: nil, left: nil, right: nil, bottom: nil),
      defaultWidth: nil,
      defaultHeight: nil
    ),
    objectMetadata: nil
  )
  let unsafeResult = NxlvRenderer().render(
    level: unsafeLevel,
    resolution: NxlvStyleResolution(assets: [unsafeAsset], diagnostics: [])
  )
  try expect(has(.unsafeGraphicPath, in: unsafeResult), "An escaping graphic path was accepted.")
}

func testLiveTerrainSceneFrame(_ styles: URL) throws {
  let retainedResult = try render(
    level(
      """
      TITLE Retained live layers
      THEME test
      WIDTH 3
      HEIGHT 1
      $TERRAIN
        STYLE test
        PIECE blue
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let retained = try unwrap(retainedResult.renderedLevel, "The retained-layer fixture did not render.")
  try expect(retained.backgroundRGBA.count == 12, "The background layer was not retained.")
  try expect(retained.terrainRGBA.count == 12, "The terrain layer was not retained.")
  try expect(retained.foregroundRGBA.count == 12, "The foreground layer was not retained.")
  try expect(
    retained.constructiveRGBA == [0xA1, 0xB2, 0xC3, 0xFF],
    "The theme MASK colour was not retained for constructed terrain."
  )

  let blue = [UInt8](arrayLiteral: 0, 0, 255, 255)
  let clear = [UInt8](arrayLiteral: 0, 0, 0, 0)
  let red = [UInt8](arrayLiteral: 255, 0, 0, 255)
  let green = [UInt8](arrayLiteral: 0, 255, 0, 255)
  let magenta = [UInt8](arrayLiteral: 255, 0, 255, 255)
  let partial = [UInt8](arrayLiteral: 0, 255, 0, 1)
  let rendered = NxlvRenderedLevel(
    width: 6,
    height: 1,
    rgba: red + red + blue + blue + green + partial,
    solidMask: [1, 1, 0, 0, 0, 1],
    steelMask: [0, 0, 0, 0, 0, 0],
    oneWayMask: [0, 0, 0, 0, 0, 0],
    oneWayEligibleMask: [0, 0, 0, 0, 0, 0],
    gadgets: [],
    terrainOpaqueMask: [1, 1, 0, 0, 0, 0],
    backgroundRGBA: blue + blue + blue + blue + blue + blue,
    terrainRGBA: red + red + clear + clear + clear + partial,
    foregroundRGBA: clear + clear + clear + clear + green + clear,
    constructiveRGBA: [255, 255, 0, 255]
  )
  var terrain = try NeoLemmixTerrain(
    width: 6,
    height: 1,
    solidMask: rendered.solidMask,
    steelMask: rendered.steelMask,
    oneWayMask: rendered.oneWayMask,
    visualOpaqueMask: rendered.terrainOpaqueMask
  )
  _ = terrain.setSolid(false, x: 0, y: 0)
  _ = terrain.setSolid(false, x: 1, y: 0)
  _ = terrain.setConstructiveSolid(x: 1, y: 0, shade: 0)
  _ = terrain.setConstructiveSolid(x: 2, y: 0, shade: 11)
  _ = terrain.setStonerSolid(x: 3, y: 0, ownerID: 7, sourceIndex: 0)
  _ = terrain.setStonerSolid(x: 4, y: 0, ownerID: 8, sourceIndex: 0)
  _ = terrain.setConstructiveSolid(x: 5, y: 0, shade: 6)

  let frame = NeoLemmixSceneFrame.rgba(
    rendered,
    terrain: terrain,
    stonerRGBA: magenta,
    stonerWidth: 1,
    stonerHeight: 1
  )
  try expect(
    pixel(frame, width: 6, x: 0, y: 0) == .blue,
    "Removed terrain did not reveal the background layer."
  )
  try expect(
    pixel(frame, width: 6, x: 1, y: 0)
      == TestColor(red: 231, green: 231, blue: 0, alpha: 255),
    "Rebuilt terrain did not replace original art with CE's first gradient step."
  )
  try expect(
    pixel(frame, width: 6, x: 2, y: 0)
      == TestColor(red: 255, green: 255, blue: 20, alpha: 255),
    "Constructed terrain did not use CE's final gradient step."
  )
  try expect(
    pixel(frame, width: 6, x: 3, y: 0) == .magenta,
    "The canonical Stoner source pixel did not enter the terrain layer."
  )
  try expect(
    pixel(frame, width: 6, x: 4, y: 0) == .green,
    "The foreground gadget did not stay above Stoner terrain."
  )
  try expect(
    pixel(frame, width: 6, x: 5, y: 0) == .yellow,
    "A constructive pixel did not replace partially transparent terrain."
  )

}

func testLiveButtonAndLockedExitStates(_ styles: URL) throws {
  let fixture = try level(
    """
    TITLE Live button states
    WIDTH 2
    HEIGHT 1
    $GADGET
      STYLE test
      PIECE button
      X 0
      Y 0
    $END
    $GADGET
      STYLE test
      PIECE button
      X 0
      Y 0
    $END
    $GADGET
      STYLE test
      PIECE locked
      X 1
      Y 0
    $END
    """
  )
  let result = try render(
    fixture,
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let rendered = try unwrap(result.renderedLevel, "The live button fixture did not render.")
  try expect(rendered.gadgets.count == 3, "The live gadget descriptors are missing.")
  try expect(rendered.gadgets.allSatisfy { $0.animationRGBA.count == 4 },
             "The primary animation frames were not retained.")
  let terrain = try NeoLemmixTerrain(width: 2, height: 1)
  let zones = [
    NeoLemmixZone(id: 0, effect: .unlockButton, bounds: .init(x: 0, y: 0, width: 1, height: 1)),
    NeoLemmixZone(id: 1, effect: .unlockButton, bounds: .init(x: 0, y: 0, width: 1, height: 1)),
    NeoLemmixZone(id: 2, effect: .lockedExit, bounds: .init(x: 1, y: 0, width: 1, height: 1)),
  ]
  let locked = NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, zones: zones)
  try expect(pixel(locked, width: 2, x: 0, y: 0) == .green,
             "An unpressed button did not use CE frame 1.")
  try expect(pixel(locked, width: 2, x: 1, y: 0) == .green,
             "A locked exit did not use CE frame 1.")

  let transitioning = NeoLemmixSceneFrame.rgba(
    rendered,
    terrain: terrain,
    zones: zones,
    disabledZoneIDs: [1],
    gadgetAnimationFrames: [0: 1, 1: 2, 2: 3]
  )
  try expect(pixel(transitioning, width: 2, x: 0, y: 0) == .blue,
             "A pressed button did not render its live transition frame.")
  try expect(pixel(transitioning, width: 2, x: 1, y: 0) == .yellow,
             "An unlocking exit did not render its live transition frame.")

  let open = NeoLemmixSceneFrame.rgba(
    rendered,
    terrain: terrain,
    zones: zones,
    disabledZoneIDs: [0, 1]
  )
  try expect(pixel(open, width: 2, x: 0, y: 0) == .red,
             "A pressed button did not settle on CE frame 0.")
  try expect(pixel(open, width: 2, x: 1, y: 0) == .red,
             "An unlocked exit did not settle on CE frame 0.")

  let noButton = NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, zones: [zones[2]])
  try expect(pixel(noButton, width: 2, x: 1, y: 0) == .red,
             "A locked exit with no buttons did not start open.")

  let staticOpenResult = try render(
    level(
      """
      TITLE Static open locked exit
      WIDTH 1
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE locked
        X 0
        Y 0
      $END
      """
    ),
    styles: styles
  )
  let staticOpen = try unwrap(
    staticOpenResult.renderedLevel,
    "The static open locked-exit fixture did not render."
  )
  try expect(pixel(staticOpen, x: 0, y: 0) == .red,
             "Static rendering left a no-button locked exit on frame 1.")

  let trapResult = try render(
    level(
      """
      TITLE Live trap state
      WIDTH 1
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE live_trap
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let trap = try unwrap(trapResult.renderedLevel, "The live trap fixture did not render.")
  let trapZone = NeoLemmixZone(
    id: 9,
    effect: .trap,
    bounds: .init(x: 0, y: 0, width: 1, height: 1),
    animationFrames: 4
  )
  let activeTrap = NeoLemmixSceneFrame.rgba(
    trap,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    zones: [trapZone],
    gadgetAnimationFrames: [9: 3]
  )
  try expect(pixel(activeTrap, width: 1, x: 0, y: 0) == .yellow,
             "A triggered trap did not render its live primary frame.")

  let exitResult = try render(
    level(
      """
      TITLE Always animated exit
      WIDTH 1
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE live_exit
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let animatedExit = try unwrap(exitResult.renderedLevel, "The live exit fixture did not render.")
  let exitFrame = NeoLemmixSceneFrame.rgba(
    animatedExit,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    tickCount: 3
  )
  try expect(pixel(exitFrame, width: 1, x: 0, y: 0) == .yellow,
             "An always-animated gadget did not advance with the simulation tick.")

  let entranceResult = try render(
    level(
      """
      TITLE Opening entrance
      WIDTH 1
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE live_entrance
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let entrance = try unwrap(
    entranceResult.renderedLevel,
    "The opening entrance fixture did not render."
  )
  let closedEntrance = NeoLemmixSceneFrame.rgba(
    entrance,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    tickCount: 34,
    entranceOpenTick: 35
  )
  let openingEntrance = NeoLemmixSceneFrame.rgba(
    entrance,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    tickCount: 35,
    entranceOpenTick: 35
  )
  let openedEntrance = NeoLemmixSceneFrame.rgba(
    entrance,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    tickCount: 37,
    entranceOpenTick: 35
  )
  try expect(pixel(closedEntrance, width: 1, x: 0, y: 0) == .green,
             "A closed entrance did not remain on CE frame 1.")
  try expect(pixel(openingEntrance, width: 1, x: 0, y: 0) == .blue,
             "An entrance did not advance on its opening tick.")
  try expect(pixel(openedEntrance, width: 1, x: 0, y: 0) == .red,
             "An entrance did not settle on frame 0 after opening.")

  let splitterResult = try render(
    level(
      """
      TITLE Live splitter direction
      WIDTH 1
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE live_splitter
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let splitter = try unwrap(
    splitterResult.renderedLevel,
    "The live splitter fixture did not render."
  )
  let splitterZone = NeoLemmixZone(
    id: 12,
    effect: .splitter,
    bounds: .init(x: 0, y: 0, width: 1, height: 1)
  )
  let sendsLeft = NeoLemmixSceneFrame.rgba(
    splitter,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    zones: [splitterZone],
    splitterDirections: [12: .left]
  )
  let sendsRight = NeoLemmixSceneFrame.rgba(
    splitter,
    terrain: try NeoLemmixTerrain(width: 1, height: 1),
    zones: [splitterZone],
    splitterDirections: [12: .right]
  )
  try expect(pixel(sendsLeft, width: 1, x: 0, y: 0) == .green,
             "A splitter set to send left did not render CE frame 1.")
  try expect(pixel(sendsRight, width: 1, x: 0, y: 0) == .red,
             "A splitter set to send right did not render CE frame 0.")

  let secondaryResult = try render(
    level(
      """
      TITLE Unconditional secondary animation
      WIDTH 4
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE secondary
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let secondary = try unwrap(
    secondaryResult.renderedLevel,
    "The unconditional secondary fixture did not render."
  )
  try expect(!has(.secondaryAnimationsOmitted, in: secondaryResult),
             "An unconditional secondary animation was reported as omitted.")
  try expect(pixel(secondary, x: 0, y: 0) == .red,
             "The secondary fixture lost its primary layer.")
  try expect(pixel(secondary, x: 1, y: 0) == .green,
             "The secondary fixture did not render its initial frame and offset.")
  try expect(pixel(secondary, x: 2, y: 0) == .magenta,
             "A paused secondary did not render its selected initial frame.")
  try expect(pixel(secondary, x: 3, y: 0) == .orange,
             "A loop-to-zero secondary did not render its selected initial frame.")
  let advancedSecondary = NeoLemmixSceneFrame.rgba(
    secondary,
    terrain: try NeoLemmixTerrain(width: 4, height: 1),
    tickCount: 1
  )
  try expect(pixel(advancedSecondary, width: 4, x: 1, y: 0) == .blue,
             "An unconditional secondary animation did not advance with the simulation tick.")
  try expect(pixel(advancedSecondary, width: 4, x: 2, y: 0) == .magenta,
             "A paused secondary animation advanced unexpectedly.")
  try expect(pixel(advancedSecondary, width: 4, x: 3, y: 0) == .yellow,
             "A loop-to-zero secondary did not settle on frame 0.")

  let triggeredResult = try render(
    level(
      """
      TITLE Trigger-controlled secondary animation
      WIDTH 2
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE triggered_secondary
        X 0
        Y 0
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let triggered = try unwrap(
    triggeredResult.renderedLevel,
    "The trigger-controlled secondary fixture did not render."
  )
  try expect(!has(.secondaryAnimationsOmitted, in: triggeredResult),
             "A trigger-controlled secondary was reported as omitted.")
  try expect(pixel(triggered, x: 0, y: 0) == .red && pixel(triggered, x: 1, y: 0) == .clear,
             "A hidden trigger-controlled secondary was drawn while idle.")
  let busySecondary = NeoLemmixSceneFrame.rgba(
    triggered,
    terrain: try NeoLemmixTerrain(width: 2, height: 1),
    secondaryAnimationStates: [
      0: [NeoLemmixSecondaryAnimationState(frame: 0, state: .play, isVisible: true)],
    ]
  )
  try expect(pixel(busySecondary, width: 2, x: 1, y: 0) == .green,
             "A visible BUSY secondary animation did not render.")

  let movingResult = try render(
    level(
      """
      TITLE Moving background
      WIDTH 4
      HEIGHT 1
      $GADGET
        STYLE test
        PIECE moving_background
        X 0
        Y 0
        ANGLE 4
        SPEED 17
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let moving = try unwrap(movingResult.renderedLevel, "The moving-background fixture did not render.")
  try expect(!has(.unsupportedGadget, in: movingResult),
             "A moving background was reported as unsupported.")
  try expect(pixel(moving, x: 0, y: 0) == .red,
             "A moving background lost its initial frame.")
  let moved = NeoLemmixSceneFrame.rgba(
    moving,
    terrain: try NeoLemmixTerrain(width: 4, height: 1),
    tickCount: 1
  )
  try expect(pixel(moved, width: 4, x: 0, y: 0) == .clear
                && pixel(moved, width: 4, x: 2, y: 0) == .green,
             "A moving background did not use CE direction, speed, frame, and layer timing.")
}

func testNoOverwriteWithinGadgetLayers(_ styles: URL) throws {
  let result = try render(
    level(
      """
      TITLE NO_OVERWRITE gadget layers
      WIDTH 2
      HEIGHT 1
      $TERRAIN
        STYLE test
        PIECE blue
        X 1
        Y 0
      $END
      $GADGET
        STYLE test
        PIECE no_overwrite_layers
        X 0
        Y 0
        NO_OVERWRITE
      $END
      """
    ),
    styles: styles,
    renderer: NxlvRenderer(retainsVisualLayers: true)
  )
  let rendered = try unwrap(result.renderedLevel, "The NO_OVERWRITE layer fixture did not render.")
  try expect(
    pixel(rendered, x: 0, y: 0) == .green,
    "NO_OVERWRITE blocked a later Z-layer from the same gadget."
  )
  try expect(
    pixel(rendered, x: 1, y: 0) == .blue,
    "NO_OVERWRITE replaced existing terrain."
  )

  let live = NeoLemmixSceneFrame.rgba(
    rendered,
    terrain: try NeoLemmixTerrain(
      width: 2,
      height: 1,
      solidMask: rendered.solidMask,
      steelMask: rendered.steelMask,
      oneWayMask: rendered.oneWayMask,
      visualOpaqueMask: rendered.terrainOpaqueMask
    )
  )
  try expect(
    pixel(live, width: 2, x: 0, y: 0) == .green,
    "Live NO_OVERWRITE compositing blocked a later Z-layer from the same gadget."
  )
  try expect(
    pixel(live, width: 2, x: 1, y: 0) == .blue,
    "Live NO_OVERWRITE compositing replaced existing terrain."
  )
}

@main
struct NxlvRendererTests {
  static func main() throws {
    let fixture = FileManager.default.temporaryDirectory
      .appendingPathComponent("NxlvRendererTests-\(UUID().uuidString)", isDirectory: true)
    let styles = fixture.appendingPathComponent("styles", isDirectory: true)
    try FileManager.default.createDirectory(at: styles, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: fixture) }

    try makeTerrainFixtures(styles)
    try makeObjectFixtures(styles)
    try testTransforms(styles)
    try testTerrainCompositionAndOneWay(styles)
    try testGroups(styles)
    try testNineSliceAndDefaults(styles)
    try testRemainderAnimationStrip(styles)
    try testBackgroundAndPrimaryGadget(styles)
    try testPaintClipsToTerrain(styles)
    try testTriggerOutsideGraphic(styles)
    try testPNGAndPathLimits(fixture)
    try testLiveTerrainSceneFrame(styles)
    try testLiveButtonAndLockedExitStates(styles)
    try testNoOverwriteWithinGadgetLayers(styles)
    print(
      "NXLV renderer tests passed: transforms, terrain flags, masks, groups, resize, clipping, live terrain layers, and PNG safety."
    )
  }
}
