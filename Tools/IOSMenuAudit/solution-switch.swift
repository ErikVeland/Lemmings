import CoreGraphics
import Foundation
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkSolutionSwitch(library: ClassicMobileLibrary, typography: GameMenuTypography,
                                              resources: URL, output: URL) throws {
        let content = try library.loadLevel(at: 0)
        guard let live = content.session as? ClassicMobileSession,
              let solution = VerifiedSolution.load(initial: live.initialSimulation, from: resources),
              let replay = try live.makeReplaySession(document: JSONEncoder().encode(solution.replay)) else { throw Failure.missingArtwork }
        let liveState = live.snapshot
        let checkpoint = try JSONSerialization.jsonObject(with: live.checkpointPayload()) as! NSDictionary
        let moves = replay.replayMoveNavigation
        guard !moves.ticks.isEmpty else { throw invalidTargets(line: #line) }
        let states = [0, moves.ticks.first!, moves.ticks.last!, solution.replay.expected!.ticks]
        var renders = 0
        for (pose, viewport) in [("phone", CGSize(width: 390, height: 763)), ("narrow", CGSize(width: 320, height: 548)),
                                  ("landscape", CGSize(width: 756, height: 369)), ("ipad", CGSize(width: 1112, height: 814)),
                                  ("tv", CGSize(width: 1920, height: 1080)), ("tv-hd", CGSize(width: 1280, height: 720)),
                                  ("tv-safe", CGSize(width: 1920, height: 1080))] {
            for mode in SolutionReplayMode.allCases {
                for (index, tick) in states.enumerated() {
                    guard replay.seekReplay(to: tick) else { throw invalidTargets(line: #line) }
                    let session = mode == .game ? live : replay
                    let summary = MobilePauseSummary(level: content.summary, snapshot: session.snapshot,
                        activeCount: session.activeLemmingCount, ticksPerSecond: session.ticksPerSecond, speed: 1,
                        assignedSkills: session.assignedSkillCount, supportsRewind: session.supportsRewind,
                        usedRewind: session.usedRewind, isReplay: mode == .solution,
                        soundtrack: "Original", track: "Lemming 1", audio: "Music paused")
                    let actions: [GameFrontEnd.Action] = mode == .game
                        ? [.init("library", "Library"), .init("restart", "Restart level"), .init("resume", "Resume", primary: true)]
                        : [.init("back", "Back to game"),
                           .init("previous", "Previous move", enabled: moves.target(from: tick, direction: -1) != nil),
                           .init("next", "Next move", enabled: moves.target(from: tick, direction: 1) != nil),
                           .init("play", session.snapshot.isComplete ? "Replay" : "Play", primary: true)]
                    let style: MobileSolutionSelectorArt.Style = pose.hasPrefix("tv") ? .television : .touch
                    let region = pose == "tv-safe" ? CGRect(x: 96, y: 54, width: 1728, height: 972)
                        : CGRect(origin: .zero, size: viewport)
                    let presentation = MobileSolutionSelectorArt.presentation(in: region,
                        showsGhost: mode == .game, style: style)
                    let selector = presentation.controls, selectorScale = presentation.scale
                    let selectorLayout = MobileSolutionSelectorArt.layout(width: selector.width / selectorScale,
                        showsGhost: mode == .game, style: style)
                    let body = presentation.content
                    guard region.contains(selector), region.contains(body), !selector.intersects(body)
                    else { throw invalidTargets(line: #line) }
                    let bodyHeight = body.height
                    let scale = MobilePauseArt.interfaceScale(.standard, width: body.width, height: bodyHeight, television: pose.hasPrefix("tv"))
                    let page = MobilePauseArt.page(summary, actions: actions)
                    let base = MobilePauseArt.layout(page, width: body.width / scale,
                        minimumHeight: bodyHeight / scale, television: pose.hasPrefix("tv"))
                    let layout = MobilePauseArt.pinningFooter(base, viewport: CGRect(x: 0, y: 0, width: body.width / scale, height: bodyHeight / scale))
                    if pose.hasPrefix("tv"), let shelf = layout.targets.map(\.frame.minY).min() {
                        guard layout.preview.maxY < shelf,
                              layout.details.prefix(11).allSatisfy({ $0.maxY < shelf })
                        else { throw invalidTargets(line: #line) }
                    }
                    for (targetIndex, frame) in selectorLayout.targets.enumerated() {
                        guard frame.height * selectorScale >= 44, frame.width * selectorScale >= 44,
                              CGRect(origin: .zero, size: selectorLayout.size).contains(frame),
                              !selectorLayout.targets.enumerated().contains(where: { $0.offset != targetIndex && $0.element.intersects(frame) })
                        else { throw invalidTargets(line: #line) }
                    }
                    if let ghost = selectorLayout.ghost {
                        guard ghost.width == selectorLayout.size.width,
                              typography.width(of: "Ghost solution", face: .small, scale: 1) <= ghost.width - 128
                        else { throw invalidTargets(line: #line) }
                    }
                    for target in layout.targets {
                        if pose.hasPrefix("tv") {
                            guard target.frame.maxY * scale <= bodyHeight else { throw invalidTargets(line: #line) }
                        }
                        guard GameTextLayout.height(target.action.title, width: target.frame.width - (target.action.primary ? 48 : 24)) <= target.frame.height - 8,
                              layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                        else { throw invalidTargets(line: #line) }
                    }
                    guard let context = CGContext(data: nil, width: Int(viewport.width), height: Int(viewport.height),
                        bitsPerComponent: 8, bytesPerRow: Int(viewport.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
                    context.translateBy(x: 0, y: viewport.height); context.scaleBy(x: 1, y: -1)
                    context.saveGState()
                    context.translateBy(x: selector.minX, y: selector.minY); context.scaleBy(x: selectorScale, y: selectorScale)
                    MobileSolutionSelectorArt.draw(mode: mode, ghostEnabled: index % 2 == 1,
                        focusedIndex: pose.hasPrefix("tv") && index > 0
                            ? (index == 2 && mode == .game ? 2 : min(index - 1, selectorLayout.targets.count - 1)) : nil,
                        layout: selectorLayout, typography: typography, context: context)
                    context.restoreGState()
                    context.translateBy(x: body.minX, y: body.minY); context.scaleBy(x: scale, y: scale)
                    let frame = MobileBitmapRenderer.image(try session.render(highlight: nil))
                    GameFrontEnd.draw(page, layout: layout, typography: typography, preview: frame, in: context)
                    guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                        output.appendingPathComponent("\(pose)-\(mode.rawValue)-\(index).png") as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                    renders += 1
                }
            }
        }
        guard live.snapshot == liveState, live.snapshot.tick == 0 else { throw invalidTargets(line: #line) }
        guard checkpoint.isEqual(try JSONSerialization.jsonObject(with: live.checkpointPayload())) else { throw invalidTargets(line: #line) }
        for width: CGFloat in [280, 304, 374, 600] {
            let size = CGSize(width: width, height: ReplayMoveArt.height(width: width))
            guard SolutionSwitchArt.frames(in: CGRect(origin: .zero, size: size)).allSatisfy({
                GameTextLayout.height("Previous move", width: $0.width - 16) <= $0.height - 12
                    && $0.height >= 44 && $0.width >= 44
            }) else { throw invalidTargets(line: #line) }
            guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
            context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
            ReplayMoveArt.draw(previous: false, next: true, in: CGRect(origin: .zero, size: size), typography: typography, context: context)
            guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                output.appendingPathComponent("move-buttons-\(Int(width)).png") as CFURL, "public.png" as CFString, 1, nil)
            else { throw Failure.missingArtwork }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
        }
        print("PASS \(renders) game/solution renders and targets; replay boundaries, successful moves and unchanged live attempt.")
    }
}
