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
    try testPNGAndPathLimits(fixture)
    print(
      "NXLV renderer tests passed: transforms, terrain flags, masks, groups, resize, clipping, static layers, and PNG safety."
    )
  }
}
