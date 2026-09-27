import Foundation

/// Rebuilds the visible NeoLemmix scene from retained render layers and the
/// current physics terrain. Foreground gadgets stay above live terrain edits.
public enum NeoLemmixSceneFrame {
    public static func rgba(
        _ rendered: NxlvRenderedLevel,
        terrain current: NeoLemmixTerrain,
        stonerRGBA: [UInt8] = [],
        stonerWidth: Int = 16,
        stonerHeight: Int = 11,
        zones: [NeoLemmixZone] = [],
        disabledZoneIDs: Set<Int> = [],
        gadgetAnimationFrames: [Int: Int]? = nil,
        secondaryAnimationStates: [Int: [NeoLemmixSecondaryAnimationState]]? = nil,
        tickCount: Int = 0,
        entranceOpenTick: Int? = nil,
        splitterDirections: [Int: NeoLemmixDirection]? = nil
    ) -> [UInt8] {
        let pixelCount = rendered.width * rendered.height
        let byteCount = pixelCount * 4
        guard current.width == rendered.width,
              current.height == rendered.height,
              rendered.backgroundRGBA.count == byteCount,
              rendered.terrainRGBA.count == byteCount,
              rendered.foregroundRGBA.count == byteCount,
              rendered.solidMask.count == pixelCount,
              current.solidMask.count == pixelCount else {
            return rendered.rgba
        }

        let maskColor = rendered.constructiveRGBA.count == 4
            ? rendered.constructiveRGBA : [0xD0, 0xB0, 0x80, 0xFF]
        var terrain = rendered.terrainRGBA
        for index in 0..<pixelCount {
            let wasSolid = rendered.solidMask[index] != 0
            let isSolid = current.solidMask[index] != 0
            let offset = index * 4
            if !isSolid {
                terrain[offset + 3] = 0
            } else if let shade = current.constructionShade(
                x: index % rendered.width,
                y: index / rendered.width
            ) {
                let color = constructiveColor(maskColor, shade: shade)
                terrain[offset] = color[0]
                terrain[offset + 1] = color[1]
                terrain[offset + 2] = color[2]
                terrain[offset + 3] = color[3]
            } else if let sourceIndex = current.stonerSourceIndex(
                x: index % rendered.width,
                y: index / rendered.width
            ) {
                if stonerWidth > 0, stonerHeight > 0,
                   stonerRGBA.count == stonerWidth * stonerHeight * 4,
                   sourceIndex < stonerWidth * stonerHeight {
                    let sourceOffset = sourceIndex * 4
                    terrain[offset] = stonerRGBA[sourceOffset]
                    terrain[offset + 1] = stonerRGBA[sourceOffset + 1]
                    terrain[offset + 2] = stonerRGBA[sourceOffset + 2]
                    terrain[offset + 3] = stonerRGBA[sourceOffset + 3]
                } else {
                    terrain[offset] = maskColor[0]
                    terrain[offset + 1] = maskColor[1]
                    terrain[offset + 2] = maskColor[2]
                    terrain[offset + 3] = maskColor[3]
                }
            } else if !wasSolid {
                // Stoners are drawn from their canonical external artwork by
                // the native playfield. This fallback covers old saved states
                // that predate visual provenance.
                terrain[offset] = maskColor[0]
                terrain[offset + 1] = maskColor[1]
                terrain[offset + 2] = maskColor[2]
                terrain[offset + 3] = maskColor[3]
            }
        }

        var result = rendered.backgroundRGBA
        composite(terrain, over: &result)
        if !rendered.gadgets.isEmpty,
           rendered.gadgets.allSatisfy({ !$0.animationRGBA.isEmpty }) {
            var foreground = Array(repeating: UInt8(0), count: byteCount)
            let hasButtons = zones.contains { $0.effect == .unlockButton }
            let hasUnpressedButton = zones.contains {
                $0.effect == .unlockButton && !disabledZoneIDs.contains($0.id)
            }
            var claimedZoneIDs: Set<Int> = []
            for (visualGadgetID, gadget) in rendered.gadgets.enumerated() {
                let zone = matchingZone(
                    for: gadget,
                    in: zones,
                    excluding: claimedZoneIDs
                )
                if let zone { claimedZoneIDs.insert(zone.id) }
                let frame: Int
                if gadget.effect == .splitter, let zone,
                   let direction = splitterDirections?[zone.id] {
                    frame = direction == .left ? 1 : 0
                } else if let zone, let liveFrame = gadgetAnimationFrames?[zone.id] {
                    frame = liveFrame
                } else {
                    switch gadget.effect {
                    case .unlockButton:
                        let pressed = zone.map {
                            disabledZoneIDs.contains($0.id)
                        } ?? false
                        frame = pressed ? 0 : gadget.initialAnimationFrame
                    case .lockedExit:
                        frame = hasButtons && hasUnpressedButton ? gadget.initialAnimationFrame : 0
                    case .entrance:
                        if let entranceOpenTick, tickCount >= entranceOpenTick {
                            let openingFrame = 2 + tickCount - entranceOpenTick
                            frame = openingFrame < gadget.animationRGBA.count ? openingFrame : 0
                        } else {
                            frame = gadget.initialAnimationFrame
                        }
                    default:
                        if alwaysAnimates(gadget.effect), !gadget.animationRGBA.isEmpty {
                            frame = (gadget.initialAnimationFrame + max(0, tickCount))
                                % gadget.animationRGBA.count
                        } else {
                            frame = gadget.initialAnimationFrame
                        }
                    }
                }
                guard gadget.animationRGBA.indices.contains(frame) else { continue }
                var layers: [(
                    zIndex: Int, order: Int, rgba: [UInt8], width: Int,
                    height: Int, x: Int, y: Int
                )] = [(
                    gadget.primaryZIndex, 0, gadget.animationRGBA[frame],
                    gadget.width, gadget.height, gadget.x, gadget.y
                )]
                for (index, animation) in gadget.secondaryAnimations.enumerated()
                    where !animation.framesRGBA.isEmpty {
                    let liveState = secondaryAnimationStates?[visualGadgetID]?[safe: index]
                    if let liveState,
                       !liveState.isVisible && liveState.state == .pause { continue }
                    if liveState == nil && !animation.initiallyVisible { continue }
                    let secondaryFrame: Int
                    switch liveState?.state ?? animation.state {
                    case .play:
                        secondaryFrame = liveState?.frame
                            ?? (animation.initialFrame + max(0, tickCount))
                                % animation.framesRGBA.count
                    case .pause:
                        secondaryFrame = liveState?.frame ?? animation.initialFrame
                    case .stop:
                        secondaryFrame = 0
                    case .loopToZero:
                        if let liveState {
                            secondaryFrame = liveState.frame
                        } else {
                            let ticksToZero = animation.framesRGBA.count - animation.initialFrame
                            secondaryFrame = tickCount >= ticksToZero
                                ? 0 : animation.initialFrame + max(0, tickCount)
                        }
                    case .matchPrimary:
                        secondaryFrame = liveState?.frame ?? frame % animation.framesRGBA.count
                    }
                    guard animation.framesRGBA.indices.contains(secondaryFrame) else { continue }
                    layers.append((
                        animation.zIndex, index + 1, animation.framesRGBA[secondaryFrame],
                        animation.width, animation.height, animation.x, animation.y
                    ))
                }
                for layer in layers.sorted(by: {
                    $0.zIndex == $1.zIndex
                        ? $0.order < $1.order : $0.zIndex < $1.zIndex
                }) {
                    compositePlaced(
                        layer.rgba,
                        width: layer.width,
                        height: layer.height,
                        x: layer.x,
                        y: layer.y,
                        noOverwrite: gadget.noOverwrite,
                        canvasWidth: rendered.width,
                        canvasHeight: rendered.height,
                        over: &foreground
                    )
                }
            }
            composite(foreground, over: &result)
        } else {
            composite(rendered.foregroundRGBA, over: &result)
        }
        return result
    }

    private static func matchingZone(
        for gadget: NxlvRenderedGadget,
        in zones: [NeoLemmixZone],
        excluding claimedZoneIDs: Set<Int> = []
    ) -> NeoLemmixZone? {
        guard let x = gadget.triggerX, let y = gadget.triggerY,
              let width = gadget.triggerWidth, let height = gadget.triggerHeight else { return nil }
        return zones.first {
            !claimedZoneIDs.contains($0.id)
                && zoneEffect(for: gadget.effect) == $0.effect
                && $0.bounds == NeoLemmixRect(x: x, y: y, width: width, height: height)
        }
    }

    private static func zoneEffect(for effect: NxlvObjectEffect) -> NeoLemmixZoneEffect? {
        switch effect {
        case .unlockButton: .unlockButton
        case .lockedExit: .lockedExit
        case .trap: .trap
        case .trapOnce: .oneShotTrap
        case .splitter: .splitter
        default: nil
        }
    }

    private static func alwaysAnimates(_ effect: NxlvObjectEffect) -> Bool {
        switch effect {
        case .none, .exit, .fire, .water, .updraft, .splatPad, .antiSplatPad,
             .oneWayLeft, .oneWayRight, .oneWayDown, .oneWayUp,
             .forceLeft, .forceRight, .paint, .portal, .neutralizer,
             .deneutralizer, .removeSkills:
            true
        default:
            false
        }
    }

    public static func constructiveColor(_ maskRGBA: [UInt8], shade: Int) -> [UInt8] {
        let base = maskRGBA.count == 4 ? maskRGBA : [0xD0, 0xB0, 0x80, 0xFF]
        let delta = (min(11, max(0, shade)) - 6) * 4
        return [
            UInt8(min(255, max(0, Int(base[0]) + delta))),
            UInt8(min(255, max(0, Int(base[1]) + delta))),
            UInt8(min(255, max(0, Int(base[2]) + delta))),
            base[3],
        ]
    }

    private static func composite(_ source: [UInt8], over destination: inout [UInt8]) {
        var offset = 0
        while offset < source.count {
            compositePixel(source, at: offset, over: &destination, at: offset)
            offset += 4
        }
    }

    private static func compositePixel(
        _ source: [UInt8],
        at sourceOffset: Int,
        over destination: inout [UInt8],
        at destinationOffset: Int
    ) {
        let sourceAlpha = Int(source[sourceOffset + 3])
        if sourceAlpha == 255 {
            destination[destinationOffset] = source[sourceOffset]
            destination[destinationOffset + 1] = source[sourceOffset + 1]
            destination[destinationOffset + 2] = source[sourceOffset + 2]
            destination[destinationOffset + 3] = 255
        } else if sourceAlpha > 0 {
            let destinationAlpha = Int(destination[destinationOffset + 3])
            let inverseSourceAlpha = 255 - sourceAlpha
            let alphaScale = sourceAlpha * 255 + destinationAlpha * inverseSourceAlpha
            let outputAlpha = (alphaScale + 127) / 255
            for channel in 0..<3 {
                let numerator = Int(source[sourceOffset + channel]) * sourceAlpha * 255
                    + Int(destination[destinationOffset + channel]) * destinationAlpha
                        * inverseSourceAlpha
                destination[destinationOffset + channel] = UInt8(
                    min(255, (numerator + alphaScale / 2) / alphaScale)
                )
            }
            destination[destinationOffset + 3] = UInt8(outputAlpha)
        }
    }

    private static func compositePlaced(
        _ source: [UInt8],
        width: Int,
        height: Int,
        x destinationX: Int,
        y destinationY: Int,
        noOverwrite: Bool,
        canvasWidth: Int,
        canvasHeight: Int,
        over destination: inout [UInt8]
    ) {
        guard width > 0, height > 0, source.count == width * height * 4 else { return }
        for sourceY in 0..<height {
            let canvasY = destinationY + sourceY
            guard canvasY >= 0, canvasY < canvasHeight else { continue }
            for sourceX in 0..<width {
                let canvasX = destinationX + sourceX
                guard canvasX >= 0, canvasX < canvasWidth else { continue }
                let sourceOffset = (sourceY * width + sourceX) * 4
                guard source[sourceOffset + 3] > 0 else { continue }
                let destinationOffset = (canvasY * canvasWidth + canvasX) * 4
                if noOverwrite && destination[destinationOffset + 3] > 0 { continue }
                compositePixel(source, at: sourceOffset, over: &destination, at: destinationOffset)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
