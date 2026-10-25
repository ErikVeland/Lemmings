#if os(iOS)
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor struct MobileDuoHUDTransitionTests {
    @Test func resizingAScrollableSkillBankKeepsTheSelectedSkillVisible() throws {
        let hud = MobileHUDView(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
        let snapshot = MobileGameSnapshot(tick: 42, released: 4, total: 10, saved: 1, required: 5,
            remainingSeconds: 120, releaseRate: 50, isComplete: false, didWin: false,
            isEndingRun: false, skills: (0..<21).map { .init(name: "Skill \($0)", count: 10) })
        func selectedButton(in view: UIView) -> UIButton? {
            if let button = view as? UIButton, button.accessibilityTraits.contains(.selected) { return button }
            return view.subviews.compactMap { selectedButton(in: $0) }.first
        }
        for size in [MobileSize(width: 834, height: 1194), .init(width: 495, height: 720), .init(width: 834, height: 1194)] {
            hud.cancelHeldControls()
            hud.frame.size = CGSize(width: size.width, height: size.height)
            let layout = MobileHUDLayout.make(container: size, safeArea: .init(), hasRate: true,
                skillCount: 21, supportsRewind: true, engineIdentifier: "neolemmix")
            hud.update(layout: layout, snapshot: snapshot, selectedSkill: 20, paused: true,
                speed: 1, endRunArmed: false, panel: nil)
            let button = try #require(selectedButton(in: hud))
            let visible = button.convert(button.bounds, to: hud)
            let deck = try #require(layout.portrait)
            #expect(deck.skills.contains(visible))
            #expect(hud.pointerAction(at: CGPoint(x: visible.midX, y: visible.midY)) == .skill(20))
        }
        hud.cancelHeldControls()
    }

    @Test func everyDirectedPoseChangeKeepsTargetsSelectionAndCancelsTheOldPress() throws {
        typealias Pose = (size: MobileSize, regions: [MobileReservedRegion])
        var poses: [Pose] = [
            (.init(width: 495, height: 720), []),
            (.init(width: 720, height: 495), []),
            (.init(width: 1194, height: 834), []),
            (.init(width: 834, height: 1194), []),
            (.init(width: 1194, height: 834), [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            (.init(width: 834, height: 1194), [.init(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))]),
            (.init(width: 650, height: 465), [.init(kind: .division, frame: .init(x: 318, y: 0, width: 14, height: 465))]),
            (.init(width: 465, height: 650), [.init(kind: .division, frame: .init(x: 0, y: 318, width: 465, height: 14))])
        ]
        for size in [MobileSize(width: 495, height: 720), .init(width: 720, height: 495)] {
            for leading in [false, true] {
                for top in [false, true] {
                    poses.append((size, [.init(kind: .occlusion, frame: .init(
                        x: leading ? 0 : size.width - 92, y: top ? 0 : size.height - 80, width: 92, height: 80))]))
                }
            }
        }
        for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
            let snapshot = MobileGameSnapshot(tick: 42, released: 4, total: 10, saved: 1, required: 5,
                remainingSeconds: 120, releaseRate: rate ? 50 : nil, isComplete: false, didWin: false,
                isEndingRun: false, skills: (0..<count).map { .init(name: "Skill \($0)", count: 10) })
            func layout(_ pose: Pose) -> MobileHUDLayout {
                MobileHUDLayout.make(container: pose.size, safeArea: .init(), hasRate: rate, skillCount: count,
                    reservedRegions: pose.regions, supportsRewind: true, engineIdentifier: engine,
                    fillsDisplayWidth: pose.regions.contains { $0.kind == .occlusion })
            }
            var layouts = poses.map { (size: $0.size, layout: layout($0)) }
            for leading in [false, true] {
                let size = MobileSize(width: 495, height: 720)
                layouts.append((size, MobileHUDLayout.make(container: size,
                    safeArea: .init(top: 10, left: leading ? 95 : 10, bottom: 44, right: leading ? 10 : 95),
                    hasRate: rate, skillCount: count, supportsRewind: true, engineIdentifier: engine,
                    navigationRail: .init(x: leading ? 4 : 404, y: 60, width: 87, height: 600))))
            }
            for (sourceIndex, source) in layouts.enumerated() {
                for (destinationIndex, destination) in layouts.enumerated() where sourceIndex != destinationIndex {
                    let hud = MobileHUDView(frame: CGRect(x: 0, y: 0, width: source.size.width, height: source.size.height))
                    var actions: [MobileHUDAction] = []
                    hud.onAction = { actions.append($0) }
                    let before = source.layout
                    hud.update(layout: before, snapshot: snapshot, selectedSkill: count - 1,
                        paused: true, speed: 1, endRunArmed: false, panel: nil)
                    let first = try #require(MobileHUDRenderer.targets(layout: before, snapshot: snapshot,
                        selectedSkill: count - 1, paused: true, speed: 1, endRunArmed: false).first { $0.action == .skill(0) })
                    let oldButton = try #require(hud.hitTest(CGPoint(x: first.inputFrame.midX, y: first.inputFrame.midY), with: nil) as? UIControl)
                    oldButton.sendActions(for: .touchDown)
                    hud.cancelHeldControls()
                    hud.frame.size = CGSize(width: destination.size.width, height: destination.size.height)
                    let after = destination.layout
                    hud.update(layout: after, snapshot: snapshot, selectedSkill: count - 1,
                        paused: true, speed: 1, endRunArmed: false, panel: nil)
                    oldButton.sendActions(for: .touchUpInside)
                    #expect(actions.isEmpty)
                    let targets = MobileHUDRenderer.targets(layout: after, snapshot: snapshot,
                        selectedSkill: count - 1, paused: true, speed: 1, endRunArmed: false)
                    for target in targets {
                        let point = CGPoint(x: target.inputFrame.midX, y: target.inputFrame.midY)
                        #expect(hud.pointerAction(at: point) == target.action)
                        let button = try #require(hud.hitTest(point, with: nil) as? UIButton)
                        #expect(button.accessibilityLabel == target.accessibilityLabel)
                        #expect(button.accessibilityTraits.contains(.selected) == (target.action == .skill(count - 1)))
                    }
                    hud.cancelHeldControls()
                }
            }
        }
    }
}
#endif
