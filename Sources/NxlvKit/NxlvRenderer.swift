import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum NxlvRenderDiagnosticSeverity: String, Sendable {
  case warning
  case error
}

public enum NxlvRenderDiagnosticCode: String, Sendable {
  case invalidLevelDimensions
  case levelPixelLimitExceeded
  case placementLimitExceeded
  case terrainGroupLimitExceeded
  case duplicateResolvedAsset
  case missingResolvedAsset
  case unsafeGraphicPath
  case unreadableGraphic
  case graphicFileTooLarge
  case nonPNGGraphic
  case malformedPNG
  case graphicDimensionLimitExceeded
  case graphicPixelLimitExceeded
  case invalidPlacement
  case invalidResize
  case unsupportedResize
  case invalidNineSlice
  case duplicateTerrainGroup
  case unnamedTerrainGroup
  case missingTerrainGroup
  case forwardTerrainGroupReference
  case emptyTerrainGroup
  case mixedTerrainGroupMaterial
  case terrainGroupPixelLimitExceeded
  case conflictingTerrainFlags
  case invalidAnimationStrip
  case randomInitialFrame
  case secondaryAnimationsOmitted
  case unsupportedGadget
}

public struct NxlvRenderDiagnostic: Sendable, Equatable {
  public let severity: NxlvRenderDiagnosticSeverity
  public let code: NxlvRenderDiagnosticCode
  public let message: String
  public let line: Int?
  public let path: String?

  public init(
    severity: NxlvRenderDiagnosticSeverity,
    code: NxlvRenderDiagnosticCode,
    message: String,
    line: Int? = nil,
    path: String? = nil
  ) {
    self.severity = severity
    self.code = code
    self.message = message
    self.line = line
    self.path = path
  }
}

/// Values stored in `NxlvRenderedLevel.oneWayMask`.
public enum NxlvOneWayDirection: UInt8, Sendable, CaseIterable {
  case none = 0
  case left = 1
  case right = 2
  case up = 3
  case down = 4
}

public struct NxlvRendererLimits: Sendable, Equatable {
  public var maximumLevelDimension: Int
  public var maximumLevelPixels: Int
  public var maximumGraphicDimension: Int
  public var maximumGraphicPixels: Int
  public var maximumGraphicFileBytes: Int
  public var maximumTerrainGroupPixels: Int
  public var maximumDecodedGraphicPixels: Int
  public var maximumPlacements: Int
  public var maximumTerrainGroups: Int

  public init(
    maximumLevelDimension: Int = 16_384,
    maximumLevelPixels: Int = 8_388_608,
    maximumGraphicDimension: Int = 8_192,
    maximumGraphicPixels: Int = 16_777_216,
    maximumGraphicFileBytes: Int = 67_108_864,
    maximumTerrainGroupPixels: Int = 16_777_216,
    maximumDecodedGraphicPixels: Int = 33_554_432,
    maximumPlacements: Int = 100_000,
    maximumTerrainGroups: Int = 4_096
  ) {
    self.maximumLevelDimension = max(1, maximumLevelDimension)
    self.maximumLevelPixels = max(1, maximumLevelPixels)
    self.maximumGraphicDimension = max(1, maximumGraphicDimension)
    self.maximumGraphicPixels = max(1, maximumGraphicPixels)
    self.maximumGraphicFileBytes = max(1, maximumGraphicFileBytes)
    self.maximumTerrainGroupPixels = max(1, maximumTerrainGroupPixels)
    self.maximumDecodedGraphicPixels = max(1, maximumDecodedGraphicPixels)
    self.maximumPlacements = max(1, maximumPlacements)
    self.maximumTerrainGroups = max(1, maximumTerrainGroups)
  }
}

public struct NxlvRenderedGadget: Sendable, Equatable {
  public let style: String
  public let piece: String
  public let effect: NxlvObjectEffect
  public let x: Int
  public let y: Int
  public let width: Int
  public let height: Int
  public let triggerX: Int?
  public let triggerY: Int?
  public let triggerWidth: Int?
  public let triggerHeight: Int?

  public init(
    style: String,
    piece: String,
    effect: NxlvObjectEffect,
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    triggerX: Int?,
    triggerY: Int?,
    triggerWidth: Int?,
    triggerHeight: Int?
  ) {
    self.style = style
    self.piece = piece
    self.effect = effect
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.triggerX = triggerX
    self.triggerY = triggerY
    self.triggerWidth = triggerWidth
    self.triggerHeight = triggerHeight
  }
}

public struct NxlvRenderedLevel: Sendable {
  public let width: Int
  public let height: Int
  /// Top-to-bottom, left-to-right, non-premultiplied RGBA8 pixels.
  public let rgba: [UInt8]
  /// One byte per pixel. A nonzero byte is solid terrain.
  public let solidMask: [UInt8]
  /// One byte per pixel. A nonzero byte is steel terrain.
  public let steelMask: [UInt8]
  /// One byte per pixel. Values use `NxlvOneWayDirection`.
  public let oneWayMask: [UInt8]
  /// One byte per pixel. This is the terrain selected by the `ONE_WAY` flag.
  public let oneWayEligibleMask: [UInt8]
  public let gadgets: [NxlvRenderedGadget]

  public init(
    width: Int,
    height: Int,
    rgba: [UInt8],
    solidMask: [UInt8],
    steelMask: [UInt8],
    oneWayMask: [UInt8],
    oneWayEligibleMask: [UInt8],
    gadgets: [NxlvRenderedGadget]
  ) {
    self.width = width
    self.height = height
    self.rgba = rgba
    self.solidMask = solidMask
    self.steelMask = steelMask
    self.oneWayMask = oneWayMask
    self.oneWayEligibleMask = oneWayEligibleMask
    self.gadgets = gadgets
  }
}

public struct NxlvRenderResult: Sendable {
  public let renderedLevel: NxlvRenderedLevel?
  public let diagnostics: [NxlvRenderDiagnostic]
  public let styleDiagnostics: [NxlvStyleDiagnostic]

  public var hasErrors: Bool {
    diagnostics.contains { $0.severity == .error }
      || styleDiagnostics.contains { $0.severity == .error }
  }

  public init(
    renderedLevel: NxlvRenderedLevel?,
    diagnostics: [NxlvRenderDiagnostic],
    styleDiagnostics: [NxlvStyleDiagnostic]
  ) {
    self.renderedLevel = renderedLevel
    self.diagnostics = diagnostics
    self.styleDiagnostics = styleDiagnostics
  }
}

/// A deterministic renderer for low-resolution NeoLemmix level graphics.
public struct NxlvRenderer: Sendable {
  public let limits: NxlvRendererLimits

  public init(limits: NxlvRendererLimits = NxlvRendererLimits()) {
    self.limits = limits
  }

  public func render(
    level: NxlvLevel,
    resolution: NxlvStyleResolution
  ) -> NxlvRenderResult {
    var engine = NxlvRenderEngine(
      level: level,
      resolution: resolution,
      limits: limits
    )
    return engine.render()
  }
}

private struct RenderAssetKey: Hashable {
  let kind: NxlvStyleAssetKind
  let style: String
  let piece: String

  init(kind: NxlvStyleAssetKind, style: String, piece: String?) {
    self.kind = kind
    self.style = Self.normalize(style)
    self.piece = Self.normalize(piece ?? "")
  }

  private static func normalize(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping.lowercased(
      with: Locale(identifier: "en_US_POSIX")
    )
  }
}

private struct RGBA: Equatable {
  var red: UInt8
  var green: UInt8
  var blue: UInt8
  var alpha: UInt8

  static let clear = RGBA(red: 0, green: 0, blue: 0, alpha: 0)
}

private struct PixelPlane {
  let width: Int
  let height: Int
  var rgba: [UInt8]
  var solid: [UInt8]
  var steel: [UInt8]
  var oneWayEligible: [UInt8]
  var trigger: [UInt8]

  init(
    width: Int,
    height: Int,
    solid: Bool = false,
    steel: Bool = false,
    oneWayEligible: Bool = false,
    trigger: Bool = false
  ) {
    self.width = width
    self.height = height
    let count = width * height
    rgba = Array(repeating: 0, count: count * 4)
    self.solid = solid ? Array(repeating: 0, count: count) : []
    self.steel = steel ? Array(repeating: 0, count: count) : []
    self.oneWayEligible = oneWayEligible ? Array(repeating: 0, count: count) : []
    self.trigger = trigger ? Array(repeating: 0, count: count) : []
  }

  init(width: Int, height: Int, rgba: [UInt8]) {
    self.width = width
    self.height = height
    self.rgba = rgba
    solid = []
    steel = []
    oneWayEligible = []
    trigger = []
  }

  func pixel(_ index: Int) -> RGBA {
    let offset = index * 4
    return RGBA(
      red: rgba[offset],
      green: rgba[offset + 1],
      blue: rgba[offset + 2],
      alpha: rgba[offset + 3]
    )
  }

  mutating func setPixel(_ pixel: RGBA, at index: Int) {
    let offset = index * 4
    rgba[offset] = pixel.red
    rgba[offset + 1] = pixel.green
    rgba[offset + 2] = pixel.blue
    rgba[offset + 3] = pixel.alpha
  }

  mutating func copyPixel(from source: PixelPlane, sourceIndex: Int, to destinationIndex: Int) {
    setPixel(source.pixel(sourceIndex), at: destinationIndex)
    if !solid.isEmpty, !source.solid.isEmpty {
      solid[destinationIndex] = source.solid[sourceIndex]
    }
    if !steel.isEmpty, !source.steel.isEmpty {
      steel[destinationIndex] = source.steel[sourceIndex]
    }
    if !oneWayEligible.isEmpty, !source.oneWayEligible.isEmpty {
      oneWayEligible[destinationIndex] = source.oneWayEligible[sourceIndex]
    }
    if !trigger.isEmpty, !source.trigger.isEmpty {
      trigger[destinationIndex] = source.trigger[sourceIndex]
    }
  }

  mutating func clearPixel(at index: Int) {
    setPixel(.clear, at: index)
    if !solid.isEmpty { solid[index] = 0 }
    if !steel.isEmpty { steel[index] = 0 }
    if !oneWayEligible.isEmpty { oneWayEligible[index] = 0 }
    if !trigger.isEmpty { trigger[index] = 0 }
  }
}

private struct PreparedTerrain {
  let plane: PixelPlane
  let isSteel: Bool
}

private struct PreparedGadget {
  let plane: PixelPlane
  let effect: NxlvObjectEffect
  let direction: NxlvOneWayDirection
  let animationOffsetX: Int
  let animationOffsetY: Int
}

private struct PreparedGadgetPlacement {
  let source: NxlvGadget
  let prepared: PreparedGadget
  let x: Int
  let y: Int
  let style: String
  let piece: String
}

private struct GroupGraphic {
  let plane: PixelPlane
  let isSteel: Bool
}

private struct IntRect {
  let x: Int
  let y: Int
  let width: Int
  let height: Int

}

private struct NxlvRenderEngine {
  let level: NxlvLevel
  let resolution: NxlvStyleResolution
  let limits: NxlvRendererLimits

  var diagnostics: [NxlvRenderDiagnostic] = []
  var assets: [RenderAssetKey: NxlvResolvedStyleAsset] = [:]
  var ambiguousAssets: Set<RenderAssetKey> = []
  var decodedGraphics: [URL: PixelPlane] = [:]
  var groups: [String: GroupGraphic] = [:]
  var declaredGroupNames: Set<String> = []
  var processedGroupNames: Set<String> = []
  var decodedGraphicPixelCount = 0
  var terrainGroupPixelCount = 0

  mutating func render() -> NxlvRenderResult {
    guard let pixelCount = validatedLevelPixelCount() else {
      return NxlvRenderResult(
        renderedLevel: nil,
        diagnostics: diagnostics,
        styleDiagnostics: resolution.diagnostics
      )
    }
    guard validateStructureLimits() else {
      return NxlvRenderResult(
        renderedLevel: nil,
        diagnostics: diagnostics,
        styleDiagnostics: resolution.diagnostics
      )
    }

    indexResolvedAssets()
    indexDeclaredGroups()
    buildTerrainGroups()

    var backgroundLayer = PixelPlane(width: level.width, height: level.height)
    var terrainLayer = PixelPlane(
      width: level.width,
      height: level.height,
      solid: true,
      steel: true,
      oneWayEligible: true
    )
    var foregroundLayer = PixelPlane(width: level.width, height: level.height)
    var oneWayMask = Array(repeating: UInt8(0), count: pixelCount)
    var renderedGadgets: [NxlvRenderedGadget] = []
    let preparedGadgets = prepareGadgets()

    drawBackground(into: &backgroundLayer)
    drawBackgroundGadgets(preparedGadgets, into: &backgroundLayer)
    drawTerrain(into: &terrainLayer)
    drawForegroundGadgets(
      preparedGadgets,
      terrain: terrainLayer,
      foreground: &foregroundLayer,
      oneWayMask: &oneWayMask,
      renderedGadgets: &renderedGadgets
    )

    var composite = backgroundLayer.rgba
    compositeLayer(terrainLayer.rgba, over: &composite)
    compositeLayer(foregroundLayer.rgba, over: &composite)

    return NxlvRenderResult(
      renderedLevel: NxlvRenderedLevel(
        width: level.width,
        height: level.height,
        rgba: composite,
        solidMask: terrainLayer.solid,
        steelMask: terrainLayer.steel,
        oneWayMask: oneWayMask,
        oneWayEligibleMask: terrainLayer.oneWayEligible,
        gadgets: renderedGadgets
      ),
      diagnostics: diagnostics,
      styleDiagnostics: resolution.diagnostics
    )
  }

  private mutating func validatedLevelPixelCount() -> Int? {
    guard level.width > 0, level.height > 0,
      level.width <= limits.maximumLevelDimension,
      level.height <= limits.maximumLevelDimension
    else {
      append(
        .error,
        .invalidLevelDimensions,
        "The level dimensions must be from 1 through \(limits.maximumLevelDimension)."
      )
      return nil
    }
    guard let count = checkedProduct(level.width, level.height),
      count <= limits.maximumLevelPixels,
      checkedProduct(count, 4) != nil
    else {
      append(
        .error,
        .levelPixelLimitExceeded,
        "The level exceeds the \(limits.maximumLevelPixels)-pixel render limit."
      )
      return nil
    }
    return count
  }

  private mutating func validateStructureLimits() -> Bool {
    guard level.terrainGroups.count <= limits.maximumTerrainGroups else {
      append(
        .error,
        .terrainGroupLimitExceeded,
        "The level exceeds the \(limits.maximumTerrainGroups)-group render limit."
      )
      return false
    }
    var count = level.terrainPieces.count
    guard let withGadgets = checkedSum(count, level.gadgets.count) else {
      append(.error, .placementLimitExceeded, "The level placement count overflows.")
      return false
    }
    count = withGadgets
    for group in level.terrainGroups {
      guard let next = checkedSum(count, group.terrain.count) else {
        append(.error, .placementLimitExceeded, "The level placement count overflows.")
        return false
      }
      count = next
    }
    guard count <= limits.maximumPlacements else {
      append(
        .error,
        .placementLimitExceeded,
        "The level exceeds the \(limits.maximumPlacements)-placement render limit."
      )
      return false
    }
    return true
  }

  private mutating func indexResolvedAssets() {
    for asset in resolution.assets {
      let key = RenderAssetKey(
        kind: asset.reference.kind,
        style: asset.reference.style,
        piece: asset.reference.piece
      )
      if assets[key] != nil {
        ambiguousAssets.insert(key)
        assets.removeValue(forKey: key)
        append(
          .error,
          .duplicateResolvedAsset,
          "The style resolution contains duplicate assets for '\(asset.reference.style):\(asset.reference.piece ?? "")'.",
          line: asset.reference.sourceLine
        )
      } else if !ambiguousAssets.contains(key) {
        assets[key] = asset
      }
    }
  }

  private mutating func indexDeclaredGroups() {
    for group in level.terrainGroups {
      guard let name = trimmed(group.name) else { continue }
      declaredGroupNames.insert(normalize(name))
    }
  }

  private mutating func buildTerrainGroups() {
    var seen: Set<String> = []
    for group in level.terrainGroups {
      guard let name = trimmed(group.name) else {
        append(
          .error,
          .unnamedTerrainGroup,
          "A terrain group has no NAME field.",
          line: group.source.openingLine
        )
        continue
      }
      let key = normalize(name)
      guard seen.insert(key).inserted else {
        append(
          .error,
          .duplicateTerrainGroup,
          "Terrain group '\(name)' is defined more than once.",
          line: group.source.openingLine
        )
        continue
      }
      if let graphic = buildTerrainGroup(group, name: name) {
        groups[key] = graphic
      }
      processedGroupNames.insert(key)
    }
  }

  private mutating func buildTerrainGroup(
    _ group: NxlvTerrainGroup,
    name: String
  ) -> GroupGraphic? {
    var items: [(placement: NxlvTerrainPlacement, prepared: PreparedTerrain)] = []
    var materialKinds: Set<Bool> = []
    var bounds: IntRect?

    for placement in group.terrain {
      guard let x = placement.x, let y = placement.y else {
        append(
          .error,
          .invalidPlacement,
          "A piece in terrain group '\(name)' has no valid X or Y coordinate.",
          line: placement.source.openingLine
        )
        continue
      }
      guard let prepared = prepareTerrain(placement, withinGroup: name) else { continue }
      if !placement.erase { materialKinds.insert(prepared.isSteel) }
      let itemBounds = IntRect(
        x: x,
        y: y,
        width: prepared.plane.width,
        height: prepared.plane.height
      )
      guard let updatedBounds = union(bounds, itemBounds) else {
        append(
          .error,
          .invalidPlacement,
          "A piece in terrain group '\(name)' has coordinates outside the supported integer range.",
          line: placement.source.openingLine
        )
        return nil
      }
      bounds = updatedBounds
      items.append((placement, prepared))
    }

    if materialKinds.count > 1 {
      append(
        .error,
        .mixedTerrainGroupMaterial,
        "Terrain group '\(name)' mixes steel and non-steel pieces.",
        line: group.source.openingLine
      )
      return nil
    }
    guard let bounds, bounds.width > 0, bounds.height > 0 else {
      append(
        .error,
        .emptyTerrainGroup,
        "Terrain group '\(name)' has no renderable pieces.",
        line: group.source.openingLine
      )
      return nil
    }
    guard let groupPixels = checkedProduct(bounds.width, bounds.height),
      groupPixels <= limits.maximumTerrainGroupPixels,
      let totalGroupPixels = checkedSum(terrainGroupPixelCount, groupPixels),
      totalGroupPixels <= limits.maximumTerrainGroupPixels
    else {
      append(
        .error,
        .terrainGroupPixelLimitExceeded,
        "Terrain group '\(name)' exceeds the \(limits.maximumTerrainGroupPixels)-pixel limit.",
        line: group.source.openingLine
      )
      return nil
    }
    terrainGroupPixelCount = totalGroupPixels

    var canvas = PixelPlane(
      width: bounds.width,
      height: bounds.height,
      solid: true,
      steel: true,
      oneWayEligible: true
    )
    for item in items {
      guard let x = checkedDifference(item.placement.x ?? 0, bounds.x),
        let y = checkedDifference(item.placement.y ?? 0, bounds.y)
      else {
        append(
          .error,
          .invalidPlacement,
          "A piece in terrain group '\(name)' cannot be normalized safely.",
          line: item.placement.source.openingLine
        )
        continue
      }
      compositeTerrain(
        item.prepared,
        atX: x,
        y: y,
        noOverwrite: item.placement.noOverwrite,
        erase: item.placement.erase,
        oneWay: false,
        into: &canvas
      )
    }
    return GroupGraphic(plane: canvas, isSteel: materialKinds.first ?? false)
  }

  private mutating func drawBackground(into canvas: inout PixelPlane) {
    guard let identifier = trimmed(level.background) else { return }
    let fields = identifier.split(separator: ":", omittingEmptySubsequences: false)
    guard fields.count == 2 else { return }
    let style = String(fields[0])
    let piece = String(fields[1])
    guard let asset = resolvedAsset(kind: .background, style: style, piece: piece, line: nil),
      let url = uniqueGraphicURL(
        for: asset,
        description: "background '\(style):\(piece)'",
        line: nil
      ),
      let graphic = decodeGraphic(url, asset: asset)
    else { return }
    guard graphic.width > 0, graphic.height > 0 else { return }

    var y = 0
    while y < canvas.height {
      var x = 0
      while x < canvas.width {
        compositeVisual(
          graphic,
          atX: x,
          y: y,
          noOverwrite: false,
          clipToSolid: nil,
          into: &canvas
        )
        x += graphic.width
      }
      y += graphic.height
    }
  }

  private mutating func drawTerrain(into canvas: inout PixelPlane) {
    for placement in level.terrainPieces {
      guard let x = placement.x, let y = placement.y else {
        append(
          .error,
          .invalidPlacement,
          "A terrain piece has no valid X or Y coordinate.",
          line: placement.source.openingLine
        )
        continue
      }
      guard let prepared = prepareTerrain(placement, withinGroup: nil) else { continue }
      guard checkedSum(x, prepared.plane.width) != nil,
        checkedSum(y, prepared.plane.height) != nil
      else {
        append(
          .error,
          .invalidPlacement,
          "A terrain piece has coordinates outside the supported integer range.",
          line: placement.source.openingLine
        )
        continue
      }
      if placement.erase && placement.noOverwrite {
        append(
          .warning,
          .conflictingTerrainFlags,
          "An ERASE terrain piece also uses NO_OVERWRITE and cannot erase existing terrain.",
          line: placement.source.openingLine
        )
      }
      compositeTerrain(
        prepared,
        atX: x,
        y: y,
        noOverwrite: placement.noOverwrite,
        erase: placement.erase,
        oneWay: placement.oneWay,
        into: &canvas
      )
    }
  }

  private mutating func prepareGadgets() -> [PreparedGadgetPlacement] {
    var result: [PreparedGadgetPlacement] = []
    for gadget in level.gadgets {
      guard let x = gadget.x, let y = gadget.y else {
        append(
          .error,
          .invalidPlacement,
          "A gadget has no valid X or Y coordinate.",
          line: gadget.source.openingLine
        )
        continue
      }
      guard let style = trimmed(gadget.style), let piece = trimmed(gadget.piece),
        let prepared = prepareGadget(gadget)
      else { continue }
      guard let destinationX = checkedSum(x, prepared.animationOffsetX),
        let destinationY = checkedSum(y, prepared.animationOffsetY),
        checkedSum(destinationX, prepared.plane.width) != nil,
        checkedSum(destinationY, prepared.plane.height) != nil
      else {
        append(
          .error,
          .invalidPlacement,
          "Gadget '\(style):\(piece)' has coordinates outside the supported integer range.",
          line: gadget.source.openingLine
        )
        continue
      }
      result.append(
        PreparedGadgetPlacement(
          source: gadget,
          prepared: prepared,
          x: destinationX,
          y: destinationY,
          style: style,
          piece: piece
        ))
    }
    return result
  }

  private mutating func drawBackgroundGadgets(
    _ gadgets: [PreparedGadgetPlacement],
    into canvas: inout PixelPlane
  ) {
    for item in gadgets where item.prepared.effect == .background {
      compositeVisual(
        item.prepared.plane,
        atX: item.x,
        y: item.y,
        noOverwrite: item.source.noOverwrite,
        clipToSolid: nil,
        into: &canvas
      )
    }
  }

  private mutating func drawForegroundGadgets(
    _ gadgets: [PreparedGadgetPlacement],
    terrain: PixelPlane,
    foreground: inout PixelPlane,
    oneWayMask: inout [UInt8],
    renderedGadgets: inout [NxlvRenderedGadget]
  ) {
    for item in gadgets {
      let gadget = item.source
      let prepared = item.prepared
      let style = item.style
      let piece = item.piece
      if prepared.effect == .background { continue }
      let destinationX = item.x
      let destinationY = item.y
      let directional = prepared.direction != .none
      let clipMask: [UInt8]?
      if directional {
        clipMask = terrain.oneWayEligible
      } else if gadget.onlyOnTerrain {
        clipMask = terrain.solid
      } else {
        clipMask = nil
      }
      compositeVisual(
        prepared.plane,
        atX: destinationX,
        y: destinationY,
        noOverwrite: gadget.noOverwrite,
        clipToSolid: clipMask,
        into: &foreground
      )
      if directional {
        applyOneWayDirection(
          prepared,
          atX: destinationX,
          y: destinationY,
          terrain: terrain,
          oneWayMask: &oneWayMask
        )
      }

      let triggerBounds = transformedTriggerBounds(
        prepared.plane,
        atX: destinationX,
        y: destinationY
      )
      renderedGadgets.append(
        NxlvRenderedGadget(
          style: style,
          piece: piece,
          effect: prepared.effect,
          x: destinationX,
          y: destinationY,
          width: prepared.plane.width,
          height: prepared.plane.height,
          triggerX: triggerBounds?.x,
          triggerY: triggerBounds?.y,
          triggerWidth: triggerBounds?.width,
          triggerHeight: triggerBounds?.height
        ))
    }
  }

  private mutating func prepareTerrain(
    _ placement: NxlvTerrainPlacement,
    withinGroup groupName: String?
  ) -> PreparedTerrain? {
    guard let style = trimmed(placement.style), let piece = trimmed(placement.piece) else {
      append(
        .error,
        .invalidPlacement,
        "A terrain piece has no STYLE or PIECE value.",
        line: placement.source.openingLine
      )
      return nil
    }

    if style.caseInsensitiveCompare("*GROUP") == .orderedSame {
      let key = normalize(piece)
      guard let group = groups[key] else {
        let isForward =
          groupName != nil
          && declaredGroupNames.contains(key)
          && !processedGroupNames.contains(key)
        append(
          .error,
          isForward ? .forwardTerrainGroupReference : .missingTerrainGroup,
          isForward
            ? "Terrain group '\(piece)' is used before it is defined."
            : "Terrain group '\(piece)' is not defined.",
          line: placement.source.openingLine
        )
        return nil
      }
      if placement.width != nil || placement.height != nil {
        append(
          .error,
          .unsupportedResize,
          "Terrain group '\(piece)' cannot use WIDTH or HEIGHT.",
          line: placement.source.openingLine
        )
        return nil
      }
      var plane = transformed(
        group.plane,
        rotate: placement.rotate,
        flipHorizontal: placement.flipHorizontal,
        flipVertical: placement.flipVertical
      )
      setTerrainMaterial(
        in: &plane,
        steel: group.isSteel,
        oneWay: false
      )
      return PreparedTerrain(plane: plane, isSteel: group.isSteel)
    }

    guard
      let asset = resolvedAsset(
        kind: .terrain,
        style: style,
        piece: piece,
        line: placement.source.openingLine
      ),
      let url = uniqueGraphicURL(
        for: asset,
        description: "terrain '\(style):\(piece)'",
        line: placement.source.openingLine
      ),
      let decoded = decodeGraphic(url, asset: asset)
    else { return nil }
    let metadata = asset.terrainMetadata ?? emptyTerrainMetadata()
    guard
      let resized = resized(
        decoded,
        requestedWidth: placement.width,
        requestedHeight: placement.height,
        axes: metadata.resizeAxes,
        defaultWidth: metadata.defaultWidth,
        defaultHeight: metadata.defaultHeight,
        margins: metadata.nineSlice,
        line: placement.source.openingLine,
        description: "terrain '\(style):\(piece)'"
      )
    else { return nil }
    var plane = transformed(
      resized,
      rotate: placement.rotate,
      flipHorizontal: placement.flipHorizontal,
      flipVertical: placement.flipVertical
    )
    setTerrainMaterial(in: &plane, steel: metadata.isSteel, oneWay: false)
    return PreparedTerrain(plane: plane, isSteel: metadata.isSteel)
  }

  private mutating func prepareGadget(_ gadget: NxlvGadget) -> PreparedGadget? {
    guard let style = trimmed(gadget.style), let piece = trimmed(gadget.piece) else {
      append(
        .error,
        .invalidPlacement,
        "A gadget has no STYLE or PIECE value.",
        line: gadget.source.openingLine
      )
      return nil
    }
    guard
      let asset = resolvedAsset(
        kind: .object,
        style: style,
        piece: piece,
        line: gadget.source.openingLine
      )
    else { return nil }
    guard let metadata = asset.objectMetadata else {
      append(
        .error,
        .missingResolvedAsset,
        "Object '\(style):\(piece)' has no resolved metadata.",
        line: gadget.source.openingLine
      )
      return nil
    }
    if metadata.effect == .background, let speed = gadget.speed, speed != 0 {
      append(
        .warning,
        .unsupportedGadget,
        "Static rendering does not animate moving background gadget '\(style):\(piece)'.",
        line: gadget.source.openingLine
      )
    }
    guard let primaryIndex = metadata.animations.firstIndex(where: { $0.isPrimary }) else {
      append(
        .error,
        .missingResolvedAsset,
        "Object '\(style):\(piece)' has no resolved primary animation graphic.",
        line: gadget.source.openingLine
      )
      return nil
    }
    if metadata.animations.count > 1 {
      append(
        .warning,
        .secondaryAnimationsOmitted,
        "Static rendering uses only the primary animation for '\(style):\(piece)'.",
        line: gadget.source.openingLine
      )
    }
    let animation = metadata.animations[primaryIndex]
    let expectedBaseName = animation.name.map { "\(piece)_\($0)" } ?? piece
    let primaryURLs = asset.graphicURLs.filter {
      normalize($0.deletingPathExtension().lastPathComponent) == normalize(expectedBaseName)
    }
    guard primaryURLs.count == 1 else {
      append(
        .error,
        .missingResolvedAsset,
        "Object '\(style):\(piece)' does not have exactly one resolved primary animation graphic.",
        line: gadget.source.openingLine
      )
      return nil
    }
    guard
      let strip = decodeGraphic(primaryURLs[0], asset: asset),
      var frame = animationFrame(
        from: strip,
        animation: animation,
        effect: metadata.effect,
        line: gadget.source.openingLine,
        description: "object '\(style):\(piece)'"
      )
    else { return nil }

    setTriggerMask(
      in: &frame,
      metadata: metadata,
      line: gadget.source.openingLine,
      description: "object '\(style):\(piece)'"
    )
    guard
      let resized = resized(
        frame,
        requestedWidth: gadget.width,
        requestedHeight: gadget.height,
        axes: metadata.resizeAxes,
        defaultWidth: metadata.defaultWidth,
        defaultHeight: metadata.defaultHeight,
        margins: animation.nineSlice,
        line: gadget.source.openingLine,
        description: "object '\(style):\(piece)'"
      )
    else { return nil }
    let plane = transformed(
      resized,
      rotate: gadget.rotate,
      flipHorizontal: gadget.flipHorizontal,
      flipVertical: gadget.flipVertical
    )
    let direction = transformedDirection(
      direction(for: metadata.effect),
      rotate: gadget.rotate,
      flipHorizontal: gadget.flipHorizontal,
      flipVertical: gadget.flipVertical
    )
    return PreparedGadget(
      plane: plane,
      effect: metadata.effect,
      direction: direction,
      animationOffsetX: animation.offsetX,
      animationOffsetY: animation.offsetY
    )
  }

  private mutating func animationFrame(
    from strip: PixelPlane,
    animation: NxlvObjectAnimationMetadata,
    effect: NxlvObjectEffect,
    line: Int?,
    description: String
  ) -> PixelPlane? {
    let frameCount = animation.frames ?? 1
    guard frameCount > 0 else {
      append(
        .error, .invalidAnimationStrip, "The \(description) frame count is not positive.",
        line: line)
      return nil
    }
    let frameWidth: Int
    let frameHeight: Int
    if animation.usesHorizontalStrip {
      guard strip.width.isMultiple(of: frameCount) else {
        append(
          .error, .invalidAnimationStrip,
          "The \(description) horizontal strip has an invalid width.", line: line)
        return nil
      }
      frameWidth = strip.width / frameCount
      frameHeight = strip.height
    } else {
      guard strip.height.isMultiple(of: frameCount) else {
        append(
          .error, .invalidAnimationStrip,
          "The \(description) vertical strip has an invalid height.", line: line)
        return nil
      }
      frameWidth = strip.width
      frameHeight = strip.height / frameCount
    }
    guard frameWidth > 0, frameHeight > 0 else {
      append(
        .error, .invalidAnimationStrip, "The \(description) contains an empty frame.", line: line)
      return nil
    }

    let selectedFrame: Int
    switch animation.initialFrame {
    case .index(let index):
      if index < 0 || index >= frameCount {
        append(
          .warning,
          .invalidAnimationStrip,
          "The \(description) INITIAL_FRAME is outside its animation strip and was clamped.",
          line: line
        )
      }
      selectedFrame = min(max(0, index), frameCount - 1)
    case .random:
      selectedFrame = 0
      append(
        .warning,
        .randomInitialFrame,
        "Static rendering uses frame 0 for RANDOM INITIAL_FRAME in \(description).",
        line: line
      )
    case nil:
      selectedFrame = defaultInitialFrame(for: effect, frameCount: frameCount)
    }

    let originX = animation.usesHorizontalStrip ? selectedFrame * frameWidth : 0
    let originY = animation.usesHorizontalStrip ? 0 : selectedFrame * frameHeight
    return cropped(
      strip, rect: IntRect(x: originX, y: originY, width: frameWidth, height: frameHeight))
  }

  private func defaultInitialFrame(for effect: NxlvObjectEffect, frameCount: Int) -> Int {
    guard frameCount > 1 else { return 0 }
    switch effect {
    case .entrance, .lockedExit, .unlockButton:
      return 1
    default:
      return 0
    }
  }

  private mutating func resolvedAsset(
    kind: NxlvStyleAssetKind,
    style: String,
    piece: String,
    line: Int?
  ) -> NxlvResolvedStyleAsset? {
    let key = RenderAssetKey(kind: kind, style: style, piece: piece)
    guard !ambiguousAssets.contains(key), let asset = assets[key] else {
      append(
        .error,
        .missingResolvedAsset,
        "No resolved \(kind.rawValue) asset exists for '\(style):\(piece)'.",
        line: line
      )
      return nil
    }
    return asset
  }

  private mutating func decodeGraphic(
    _ url: URL,
    asset: NxlvResolvedStyleAsset
  ) -> PixelPlane? {
    let standardized = url.standardizedFileURL.resolvingSymlinksInPath()
    let styleRoot = asset.styleDirectoryURL.standardizedFileURL.resolvingSymlinksInPath()
    guard url.isFileURL, isDescendant(standardized, of: styleRoot) else {
      append(
        .error,
        .unsafeGraphicPath,
        "A graphic path escapes its resolved style directory.",
        line: asset.reference.sourceLine,
        path: url.path
      )
      return nil
    }
    if let cached = decodedGraphics[standardized] { return cached }

    do {
      let values = try standardized.resourceValues(forKeys: [
        .isRegularFileKey,
        .fileSizeKey,
      ])
      guard values.isRegularFile == true else {
        append(
          .error, .unreadableGraphic, "The graphic is not a regular file.", path: standardized.path)
        return nil
      }
      if let fileSize = values.fileSize, fileSize > limits.maximumGraphicFileBytes {
        append(
          .error,
          .graphicFileTooLarge,
          "The graphic exceeds the \(limits.maximumGraphicFileBytes)-byte file limit.",
          path: standardized.path
        )
        return nil
      }
    } catch {
      append(
        .error, .unreadableGraphic, "The graphic file attributes cannot be read.",
        path: standardized.path)
      return nil
    }

    let data: Data
    do {
      data = try Data(contentsOf: standardized, options: [.mappedIfSafe])
    } catch {
      append(.error, .unreadableGraphic, "The graphic cannot be read.", path: standardized.path)
      return nil
    }
    guard data.count <= limits.maximumGraphicFileBytes else {
      append(
        .error,
        .graphicFileTooLarge,
        "The graphic exceeds the \(limits.maximumGraphicFileBytes)-byte file limit.",
        path: standardized.path
      )
      return nil
    }
    guard
      let source = CGImageSourceCreateWithData(
        data as CFData,
        [kCGImageSourceShouldCache: false] as CFDictionary
      )
    else {
      append(.error, .malformedPNG, "ImageIO cannot open the PNG graphic.", path: standardized.path)
      return nil
    }
    guard let type = CGImageSourceGetType(source),
      UTType(type as String)?.conforms(to: .png) == true
    else {
      append(.error, .nonPNGGraphic, "The graphic data is not PNG.", path: standardized.path)
      return nil
    }
    guard CGImageSourceGetCount(source) == 1,
      let properties = CGImageSourceCopyPropertiesAtIndex(
        source,
        0,
        [kCGImageSourceShouldCache: false] as CFDictionary
      ) as? [CFString: Any],
      let width = integerProperty(properties[kCGImagePropertyPixelWidth]),
      let height = integerProperty(properties[kCGImagePropertyPixelHeight]),
      width > 0,
      height > 0
    else {
      append(
        .error, .malformedPNG, "The PNG has no valid image dimensions.", path: standardized.path)
      return nil
    }
    guard width <= limits.maximumGraphicDimension,
      height <= limits.maximumGraphicDimension
    else {
      append(
        .error,
        .graphicDimensionLimitExceeded,
        "The PNG exceeds the \(limits.maximumGraphicDimension)-pixel dimension limit.",
        path: standardized.path
      )
      return nil
    }
    guard let pixelCount = checkedProduct(width, height),
      pixelCount <= limits.maximumGraphicPixels,
      let byteCount = checkedProduct(pixelCount, 4)
    else {
      append(
        .error,
        .graphicPixelLimitExceeded,
        "The PNG exceeds the \(limits.maximumGraphicPixels)-pixel decode limit.",
        path: standardized.path
      )
      return nil
    }
    guard let totalDecodedPixels = checkedSum(decodedGraphicPixelCount, pixelCount),
      totalDecodedPixels <= limits.maximumDecodedGraphicPixels
    else {
      append(
        .error,
        .graphicPixelLimitExceeded,
        "Decoded graphics exceed the \(limits.maximumDecodedGraphicPixels)-pixel aggregate limit.",
        path: standardized.path
      )
      return nil
    }
    guard
      let image = CGImageSourceCreateImageAtIndex(
        source,
        0,
        [
          kCGImageSourceShouldCache: true,
          kCGImageSourceShouldCacheImmediately: true,
          kCGImageSourceShouldAllowFloat: false,
        ] as CFDictionary
      ), image.width == width, image.height == height
    else {
      append(
        .error, .malformedPNG, "ImageIO cannot decode the PNG graphic.", path: standardized.path)
      return nil
    }

    var bytes = Array(repeating: UInt8(0), count: byteCount)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Big.rawValue
      | CGImageAlphaInfo.premultipliedLast.rawValue
    let decoded = bytes.withUnsafeMutableBytes { storage -> Bool in
      guard let baseAddress = storage.baseAddress,
        let context = CGContext(
          data: baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * 4,
          space: colorSpace,
          bitmapInfo: bitmapInfo
        )
      else { return false }
      context.setBlendMode(.copy)
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard decoded else {
      append(
        .error, .malformedPNG, "A bitmap context cannot decode the PNG graphic.",
        path: standardized.path)
      return nil
    }
    unpremultiplyRGBA(&bytes)
    let plane = PixelPlane(width: width, height: height, rgba: bytes)
    decodedGraphicPixelCount = totalDecodedPixels
    decodedGraphics[standardized] = plane
    return plane
  }

  private func integerProperty(_ value: Any?) -> Int? {
    if let number = value as? NSNumber { return number.intValue }
    return nil
  }

  private func isDescendant(_ child: URL, of directory: URL) -> Bool {
    let root = directory.pathComponents
    let candidate = child.pathComponents
    guard candidate.count > root.count else { return false }
    return candidate.prefix(root.count).elementsEqual(root)
  }

  private func unpremultiplyRGBA(_ bytes: inout [UInt8]) {
    var offset = 0
    while offset < bytes.count {
      let alpha = Int(bytes[offset + 3])
      if alpha == 0 {
        bytes[offset] = 0
        bytes[offset + 1] = 0
        bytes[offset + 2] = 0
      } else if alpha < 255 {
        for channel in 0..<3 {
          let value = (Int(bytes[offset + channel]) * 255 + alpha / 2) / alpha
          bytes[offset + channel] = UInt8(min(255, value))
        }
      }
      offset += 4
    }
  }

  private mutating func resized(
    _ source: PixelPlane,
    requestedWidth: Int?,
    requestedHeight: Int?,
    axes: NxlvResizeAxes,
    defaultWidth: Int?,
    defaultHeight: Int?,
    margins: NxlvNineSliceMargins,
    line: Int?,
    description: String
  ) -> PixelPlane? {
    let width = targetDimension(
      requested: requestedWidth,
      defaultValue: defaultWidth,
      source: source.width,
      isResizable: axes.contains(.horizontal),
      axisName: "WIDTH",
      line: line,
      description: description
    )
    let height = targetDimension(
      requested: requestedHeight,
      defaultValue: defaultHeight,
      source: source.height,
      isResizable: axes.contains(.vertical),
      axisName: "HEIGHT",
      line: line,
      description: description
    )
    guard let width, let height else { return nil }
    if width == source.width, height == source.height { return source }
    guard let count = checkedProduct(width, height),
      count <= limits.maximumGraphicPixels
    else {
      append(
        .error,
        .graphicPixelLimitExceeded,
        "The resized \(description) exceeds the \(limits.maximumGraphicPixels)-pixel limit.",
        line: line
      )
      return nil
    }
    guard
      let xMap = resizeMap(
        sourceLength: source.width,
        targetLength: width,
        leading: margins.left,
        trailing: margins.right,
        enabled: axes.contains(.horizontal),
        axisName: "horizontal",
        line: line,
        description: description
      ),
      let yMap = resizeMap(
        sourceLength: source.height,
        targetLength: height,
        leading: margins.top,
        trailing: margins.bottom,
        enabled: axes.contains(.vertical),
        axisName: "vertical",
        line: line,
        description: description
      )
    else { return nil }

    var output = PixelPlane(
      width: width,
      height: height,
      solid: !source.solid.isEmpty,
      steel: !source.steel.isEmpty,
      oneWayEligible: !source.oneWayEligible.isEmpty,
      trigger: !source.trigger.isEmpty
    )
    for destinationY in 0..<height {
      let sourceY = yMap[destinationY]
      for destinationX in 0..<width {
        let sourceX = xMap[destinationX]
        output.copyPixel(
          from: source,
          sourceIndex: sourceY * source.width + sourceX,
          to: destinationY * width + destinationX
        )
      }
    }
    return output
  }

  private mutating func targetDimension(
    requested: Int?,
    defaultValue: Int?,
    source: Int,
    isResizable: Bool,
    axisName: String,
    line: Int?,
    description: String
  ) -> Int? {
    if !isResizable {
      if requested != nil {
        append(
          .warning,
          .unsupportedResize,
          "The \(description) ignores \(axisName) because its metadata does not enable that resize axis.",
          line: line
        )
      }
      return source
    }
    let result = requested ?? defaultValue ?? source
    guard result > 0, result <= limits.maximumGraphicDimension else {
      append(
        .error,
        .invalidResize,
        "The \(description) has an invalid \(axisName) value.",
        line: line
      )
      return nil
    }
    return result
  }

  private mutating func resizeMap(
    sourceLength: Int,
    targetLength: Int,
    leading: Int?,
    trailing: Int?,
    enabled: Bool,
    axisName: String,
    line: Int?,
    description: String
  ) -> [Int]? {
    guard enabled, sourceLength != targetLength else {
      return Array(0..<sourceLength)
    }
    let leading = leading ?? 0
    let trailing = trailing ?? 0
    guard leading >= 0, trailing >= 0,
      leading + trailing < sourceLength,
      leading + trailing <= targetLength
    else {
      append(
        .error,
        .invalidNineSlice,
        "The \(description) has invalid \(axisName) nine-slice margins.",
        line: line
      )
      return nil
    }
    let centerLength = sourceLength - leading - trailing
    return (0..<targetLength).map { destination in
      if destination < leading { return destination }
      if destination >= targetLength - trailing {
        return sourceLength - (targetLength - destination)
      }
      return leading + ((destination - leading) % centerLength)
    }
  }

  private func transformed(
    _ source: PixelPlane,
    rotate: Bool,
    flipHorizontal: Bool,
    flipVertical: Bool
  ) -> PixelPlane {
    let rotatedWidth = rotate ? source.height : source.width
    let rotatedHeight = rotate ? source.width : source.height
    var output = PixelPlane(
      width: rotatedWidth,
      height: rotatedHeight,
      solid: !source.solid.isEmpty,
      steel: !source.steel.isEmpty,
      oneWayEligible: !source.oneWayEligible.isEmpty,
      trigger: !source.trigger.isEmpty
    )

    for sourceY in 0..<source.height {
      for sourceX in 0..<source.width {
        var destinationX = rotate ? source.height - 1 - sourceY : sourceX
        var destinationY = rotate ? sourceX : sourceY
        if flipHorizontal { destinationX = rotatedWidth - 1 - destinationX }
        if flipVertical { destinationY = rotatedHeight - 1 - destinationY }
        output.copyPixel(
          from: source,
          sourceIndex: sourceY * source.width + sourceX,
          to: destinationY * rotatedWidth + destinationX
        )
      }
    }
    return output
  }

  private func cropped(_ source: PixelPlane, rect: IntRect) -> PixelPlane {
    var output = PixelPlane(
      width: rect.width,
      height: rect.height,
      solid: !source.solid.isEmpty,
      steel: !source.steel.isEmpty,
      oneWayEligible: !source.oneWayEligible.isEmpty,
      trigger: !source.trigger.isEmpty
    )
    for y in 0..<rect.height {
      for x in 0..<rect.width {
        output.copyPixel(
          from: source,
          sourceIndex: (rect.y + y) * source.width + rect.x + x,
          to: y * rect.width + x
        )
      }
    }
    return output
  }

  private func setTerrainMaterial(
    in plane: inout PixelPlane,
    steel: Bool,
    oneWay: Bool
  ) {
    let count = plane.width * plane.height
    if plane.solid.isEmpty { plane.solid = Array(repeating: 0, count: count) }
    if plane.steel.isEmpty { plane.steel = Array(repeating: 0, count: count) }
    if plane.oneWayEligible.isEmpty {
      plane.oneWayEligible = Array(repeating: 0, count: count)
    }
    for index in 0..<count {
      let opaque = plane.rgba[index * 4 + 3] > 0
      plane.solid[index] = opaque ? 1 : 0
      plane.steel[index] = opaque && steel ? 1 : 0
      plane.oneWayEligible[index] = opaque && oneWay && !steel ? 1 : 0
    }
  }

  private mutating func setTriggerMask(
    in plane: inout PixelPlane,
    metadata: NxlvObjectMetadata,
    line: Int?,
    description: String
  ) {
    let direction = direction(for: metadata.effect)
    let x = metadata.triggerX ?? 0
    let y = metadata.triggerY ?? 0
    let width = metadata.triggerWidth ?? (direction == .none ? 0 : plane.width)
    let height = metadata.triggerHeight ?? (direction == .none ? 0 : plane.height)
    guard width >= 0, height >= 0 else {
      append(
        .error,
        .invalidPlacement,
        "The \(description) has a negative trigger dimension.",
        line: line
      )
      return
    }
    guard width > 0, height > 0 else { return }
    guard let xEnd = checkedSum(x, width), let yEnd = checkedSum(y, height) else {
      append(
        .error,
        .invalidPlacement,
        "The \(description) trigger area exceeds the supported integer range.",
        line: line
      )
      return
    }
    let minimumY = max(0, y)
    let maximumY = min(plane.height, yEnd)
    let minimumX = max(0, x)
    let maximumX = min(plane.width, xEnd)
    guard minimumX < maximumX, minimumY < maximumY else { return }
    if plane.trigger.isEmpty {
      plane.trigger = Array(repeating: 0, count: plane.width * plane.height)
    }
    for destinationY in minimumY..<maximumY {
      for destinationX in minimumX..<maximumX {
        plane.trigger[destinationY * plane.width + destinationX] = 1
      }
    }
  }

  private func compositeTerrain(
    _ prepared: PreparedTerrain,
    atX destinationX: Int,
    y destinationY: Int,
    noOverwrite: Bool,
    erase: Bool,
    oneWay: Bool,
    into canvas: inout PixelPlane
  ) {
    let source = prepared.plane
    let clip = clippedRanges(
      sourceWidth: source.width,
      sourceHeight: source.height,
      destinationX: destinationX,
      destinationY: destinationY,
      canvasWidth: canvas.width,
      canvasHeight: canvas.height
    )
    guard let clip else { return }
    for sourceY in clip.sourceY {
      let canvasY = destinationY + sourceY
      for sourceX in clip.sourceX {
        let canvasX = destinationX + sourceX
        let sourceIndex = sourceY * source.width + sourceX
        guard source.rgba[sourceIndex * 4 + 3] > 0 else { continue }
        let destinationIndex = canvasY * canvas.width + canvasX
        if noOverwrite, canvas.solid[destinationIndex] != 0 { continue }
        if erase {
          canvas.clearPixel(at: destinationIndex)
          continue
        }
        canvas.setPixel(
          sourceOver(source.pixel(sourceIndex), canvas.pixel(destinationIndex)),
          at: destinationIndex
        )
        canvas.solid[destinationIndex] = 1
        canvas.steel[destinationIndex] = prepared.isSteel ? 1 : 0
        canvas.oneWayEligible[destinationIndex] = oneWay && !prepared.isSteel ? 1 : 0
      }
    }
  }

  private func compositeVisual(
    _ source: PixelPlane,
    atX destinationX: Int,
    y destinationY: Int,
    noOverwrite: Bool,
    clipToSolid: [UInt8]?,
    into canvas: inout PixelPlane
  ) {
    let clip = clippedRanges(
      sourceWidth: source.width,
      sourceHeight: source.height,
      destinationX: destinationX,
      destinationY: destinationY,
      canvasWidth: canvas.width,
      canvasHeight: canvas.height
    )
    guard let clip else { return }
    for sourceY in clip.sourceY {
      let canvasY = destinationY + sourceY
      for sourceX in clip.sourceX {
        let canvasX = destinationX + sourceX
        let sourceIndex = sourceY * source.width + sourceX
        let sourcePixel = source.pixel(sourceIndex)
        guard sourcePixel.alpha > 0 else { continue }
        let destinationIndex = canvasY * canvas.width + canvasX
        if let clipToSolid, clipToSolid[destinationIndex] == 0 { continue }
        if noOverwrite, canvas.rgba[destinationIndex * 4 + 3] > 0 { continue }
        canvas.setPixel(
          sourceOver(sourcePixel, canvas.pixel(destinationIndex)),
          at: destinationIndex
        )
      }
    }
  }

  private func applyOneWayDirection(
    _ prepared: PreparedGadget,
    atX destinationX: Int,
    y destinationY: Int,
    terrain: PixelPlane,
    oneWayMask: inout [UInt8]
  ) {
    let source = prepared.plane
    let clip = clippedRanges(
      sourceWidth: source.width,
      sourceHeight: source.height,
      destinationX: destinationX,
      destinationY: destinationY,
      canvasWidth: terrain.width,
      canvasHeight: terrain.height
    )
    guard let clip else { return }
    for sourceY in clip.sourceY {
      let canvasY = destinationY + sourceY
      for sourceX in clip.sourceX {
        let sourceIndex = sourceY * source.width + sourceX
        guard source.trigger[sourceIndex] != 0 else { continue }
        let canvasX = destinationX + sourceX
        let destinationIndex = canvasY * terrain.width + canvasX
        guard terrain.solid[destinationIndex] != 0,
          terrain.steel[destinationIndex] == 0,
          terrain.oneWayEligible[destinationIndex] != 0
        else { continue }
        oneWayMask[destinationIndex] = prepared.direction.rawValue
      }
    }
  }

  private func transformedTriggerBounds(
    _ plane: PixelPlane,
    atX destinationX: Int,
    y destinationY: Int
  ) -> IntRect? {
    guard !plane.trigger.isEmpty else { return nil }
    var minimumX = Int.max
    var minimumY = Int.max
    var maximumX = Int.min
    var maximumY = Int.min
    for y in 0..<plane.height {
      for x in 0..<plane.width where plane.trigger[y * plane.width + x] != 0 {
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
      }
    }
    guard minimumX != Int.max else { return nil }
    guard let x = checkedSum(destinationX, minimumX),
      let y = checkedSum(destinationY, minimumY)
    else { return nil }
    return IntRect(
      x: x,
      y: y,
      width: maximumX - minimumX + 1,
      height: maximumY - minimumY + 1
    )
  }

  private func compositeLayer(_ source: [UInt8], over destination: inout [UInt8]) {
    var offset = 0
    while offset < source.count {
      let sourcePixel = RGBA(
        red: source[offset],
        green: source[offset + 1],
        blue: source[offset + 2],
        alpha: source[offset + 3]
      )
      if sourcePixel.alpha > 0 {
        let destinationPixel = RGBA(
          red: destination[offset],
          green: destination[offset + 1],
          blue: destination[offset + 2],
          alpha: destination[offset + 3]
        )
        let result = sourceOver(sourcePixel, destinationPixel)
        destination[offset] = result.red
        destination[offset + 1] = result.green
        destination[offset + 2] = result.blue
        destination[offset + 3] = result.alpha
      }
      offset += 4
    }
  }

  private func sourceOver(_ source: RGBA, _ destination: RGBA) -> RGBA {
    if source.alpha == 0 { return destination }
    if source.alpha == 255 || destination.alpha == 0 { return source }
    let sourceAlpha = Int(source.alpha)
    let destinationAlpha = Int(destination.alpha)
    let inverseSourceAlpha = 255 - sourceAlpha
    let alphaScale = sourceAlpha * 255 + destinationAlpha * inverseSourceAlpha
    let outputAlpha = (alphaScale + 127) / 255

    func channel(_ sourceValue: UInt8, _ destinationValue: UInt8) -> UInt8 {
      let numerator =
        Int(sourceValue) * sourceAlpha * 255
        + Int(destinationValue) * destinationAlpha * inverseSourceAlpha
      return UInt8(min(255, (numerator + alphaScale / 2) / alphaScale))
    }
    return RGBA(
      red: channel(source.red, destination.red),
      green: channel(source.green, destination.green),
      blue: channel(source.blue, destination.blue),
      alpha: UInt8(outputAlpha)
    )
  }

  private func direction(for effect: NxlvObjectEffect) -> NxlvOneWayDirection {
    switch effect {
    case .oneWayLeft: .left
    case .oneWayRight: .right
    case .oneWayUp: .up
    case .oneWayDown: .down
    default: .none
    }
  }

  private func transformedDirection(
    _ initial: NxlvOneWayDirection,
    rotate: Bool,
    flipHorizontal: Bool,
    flipVertical: Bool
  ) -> NxlvOneWayDirection {
    var result = initial
    if rotate {
      switch result {
      case .left: result = .up
      case .right: result = .down
      case .up: result = .right
      case .down: result = .left
      case .none: break
      }
    }
    if flipHorizontal {
      if result == .left { result = .right } else if result == .right { result = .left }
    }
    if flipVertical {
      if result == .up { result = .down } else if result == .down { result = .up }
    }
    return result
  }

  private func clippedRanges(
    sourceWidth: Int,
    sourceHeight: Int,
    destinationX: Int,
    destinationY: Int,
    canvasWidth: Int,
    canvasHeight: Int
  ) -> (sourceX: Range<Int>, sourceY: Range<Int>)? {
    guard let destinationMaximumX = checkedSum(destinationX, sourceWidth),
      let destinationMaximumY = checkedSum(destinationY, sourceHeight)
    else { return nil }
    let overlapMinimumX = max(0, destinationX)
    let overlapMinimumY = max(0, destinationY)
    let overlapMaximumX = min(canvasWidth, destinationMaximumX)
    let overlapMaximumY = min(canvasHeight, destinationMaximumY)
    guard overlapMinimumX < overlapMaximumX,
      overlapMinimumY < overlapMaximumY,
      let sourceMinimumX = checkedDifference(overlapMinimumX, destinationX),
      let sourceMinimumY = checkedDifference(overlapMinimumY, destinationY),
      let sourceMaximumX = checkedDifference(overlapMaximumX, destinationX),
      let sourceMaximumY = checkedDifference(overlapMaximumY, destinationY)
    else { return nil }
    return (sourceMinimumX..<sourceMaximumX, sourceMinimumY..<sourceMaximumY)
  }

  private func union(_ lhs: IntRect?, _ rhs: IntRect) -> IntRect? {
    guard let rhsMaximumX = checkedSum(rhs.x, rhs.width),
      let rhsMaximumY = checkedSum(rhs.y, rhs.height)
    else { return nil }
    guard let lhs else { return rhs }
    guard let lhsMaximumX = checkedSum(lhs.x, lhs.width),
      let lhsMaximumY = checkedSum(lhs.y, lhs.height)
    else { return nil }
    let minimumX = min(lhs.x, rhs.x)
    let minimumY = min(lhs.y, rhs.y)
    let maximumX = max(lhsMaximumX, rhsMaximumX)
    let maximumY = max(lhsMaximumY, rhsMaximumY)
    guard let width = checkedDifference(maximumX, minimumX),
      let height = checkedDifference(maximumY, minimumY)
    else { return nil }
    return IntRect(
      x: minimumX,
      y: minimumY,
      width: width,
      height: height
    )
  }

  private func checkedSum(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? nil : result.partialValue
  }

  private func checkedDifference(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.subtractingReportingOverflow(rhs)
    return result.overflow ? nil : result.partialValue
  }

  private func checkedProduct(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    return result.overflow ? nil : result.partialValue
  }

  private mutating func uniqueGraphicURL(
    for asset: NxlvResolvedStyleAsset,
    description: String,
    line: Int?
  ) -> URL? {
    guard asset.graphicURLs.count == 1 else {
      append(
        .error,
        .missingResolvedAsset,
        "The \(description) does not have exactly one resolved graphic.",
        line: line
      )
      return nil
    }
    return asset.graphicURLs[0]
  }

  private func normalize(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping.lowercased(
      with: Locale(identifier: "en_US_POSIX")
    )
  }

  private func trimmed(_ value: String?) -> String? {
    guard let value else { return nil }
    let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? nil : result
  }

  private func emptyTerrainMetadata() -> NxlvTerrainMetadata {
    NxlvTerrainMetadata(
      isSteel: false,
      isDeprecated: false,
      resizeAxes: [],
      nineSlice: NxlvNineSliceMargins(top: nil, left: nil, right: nil, bottom: nil),
      defaultWidth: nil,
      defaultHeight: nil
    )
  }

  private mutating func append(
    _ severity: NxlvRenderDiagnosticSeverity,
    _ code: NxlvRenderDiagnosticCode,
    _ message: String,
    line: Int? = nil,
    path: String? = nil
  ) {
    diagnostics.append(
      NxlvRenderDiagnostic(
        severity: severity,
        code: code,
        message: message,
        line: line,
        path: path
      ))
  }
}
