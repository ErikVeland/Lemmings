#if os(iOS) || os(tvOS)
import Foundation
import LemmingsMobileCore
import NxlvKit
import UIKit

public enum LemmingsMobileApplication {
    @MainActor public static func makeRootViewController() -> UIViewController {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-l3-direction-picker")
            || ProcessInfo.processInfo.arguments.contains("--ui-test-accessible-targeting")
            || ProcessInfo.processInfo.arguments.contains("--ui-test-accessible-assignment") {
            return MobileInteractionUITestHarness.make()
        }
#endif
        #if os(tvOS)
        return MobileTVBootstrap()
        #else
        return MobileLibraryViewController()
        #endif
    }
}

#if DEBUG
@MainActor private enum MobileInteractionUITestHarness {
    static func make() -> UIViewController {
        do {
            let width = 128
            let height = 64
            var attributes = [UInt16](repeating: 0x1000, count: width * height)
            for y in 48..<height {
                for x in 0..<width { attributes[y * width + x] = 0x20 }
            }
            let runtime = try Lemmings3Runtime(configuration: .init(
                width: width,
                height: height,
                attributes: attributes,
                entrance: .init(x: 20, y: 40),
                exits: [.init(x: 110, y: 46)],
                total: 1,
                releaseInterval: 20,
                releaseDelay: 1_000,
                pickups: [.init(id: 0, tool: .bricks, x: 20, y: 48)],
                extras: [.init(x: 20, y: 48, direction: 1)]
            ))
            let renderer: Lemmings3MobileRenderer = { current, _ in
                var rgba = [UInt8](repeating: 0, count: width * height * 4)
                for y in 48..<height {
                    for x in 0..<width {
                        let offset = (y * width + x) * 4
                        rgba[offset] = 56
                        rgba[offset + 1] = 112
                        rgba[offset + 2] = 56
                        rgba[offset + 3] = 255
                    }
                }
                for lemming in current.lemmings where lemming.active {
                    for y in max(0, lemming.y - 5)..<min(height, lemming.y) {
                        for x in max(0, lemming.x - 2)..<min(width, lemming.x + 3) {
                            let offset = (y * width + x) * 4
                            rgba[offset] = 236
                            rgba[offset + 1] = 242
                            rgba[offset + 2] = 198
                            rgba[offset + 3] = 255
                        }
                    }
                }
                return try MobilePixelFrame(width: width, height: height, rgba: Data(rgba))
            }
            let session = Lemmings3MobileSession(
                runtime: runtime,
                engineFingerprint: "ios-direction-picker-test",
                levelIdentifier: "ios-test/l3-direction",
                levelIndex: 0,
                levelFingerprint: "ios-test/l3-direction-level",
                directionPickerFrames: try directionFrames(),
                renderer: renderer
            )
            session.tick()
            let control = requireUseControl()
            guard let candidate = session.targetCandidates(for: control).first(where: { $0.assignment == .eligible }) else {
                preconditionFailure(L10n.text("The synthetic Lemmings 3 level must include an eligible tool holder."))
            }
            let selection = MobileTargetSelection(id: candidate.id, point: candidate.point, state: candidate.assignment)
            let summary = MobileLevelSummary(index: 0, rank: L10n.text("UI TEST"), number: 1, title: L10n.text("L3 direction"))
            let checkpoint = MobileCheckpointStore(url: FileManager.default.temporaryDirectory
                .appendingPathComponent("L3DirectionPicker-\(UUID().uuidString).json"))
            let game = MobileGameViewController(summary: summary, session: session,
                checkpointStore: checkpoint, restoredCheckpoint: nil)
            return MobileInteractionTestHostController(
                game: game,
                selection: selection,
                control: control,
                opensDirectionPicker: ProcessInfo.processInfo.arguments.contains("--ui-test-l3-direction-picker"),
                checksAccessibleTargeting: ProcessInfo.processInfo.arguments.contains("--ui-test-accessible-targeting")
                    || ProcessInfo.processInfo.arguments.contains("--ui-test-accessible-assignment"),
                assignsAccessibly: ProcessInfo.processInfo.arguments.contains("--ui-test-accessible-assignment")
            )
        } catch {
            preconditionFailure(L10n.text("Could not build the Lemmings 3 direction-picker test level: \(error)"))
        }
    }

    private static func requireUseControl() -> Int {
        guard let index = Lemmings3Runtime.Action.allCases.firstIndex(of: .use) else {
            preconditionFailure(L10n.text("Lemmings 3 must define its native Use control."))
        }
        return index
    }

    private static func directionFrames() throws -> [MobilePixelFrame] {
        try (0..<8).map { frameIndex in
            guard let direction = Lemmings3Runtime.Direction.allCases.first(where: {
                MobileDirectionPickerLayout.frameIndex(for: $0) == frameIndex
            }) else { throw MobileSessionError.invalidFrame }
            return try directionFrame(for: direction)
        }
    }

    private static func directionFrame(for direction: Lemmings3Runtime.Direction) throws -> MobilePixelFrame {
        let width = 16
        let height = 16
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        func setPixel(_ x: Int, _ y: Int) {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return }
            let offset = (y * width + x) * 4
            rgba[offset] = 76
            rgba[offset + 1] = 232
            rgba[offset + 2] = 84
            rgba[offset + 3] = 255
        }
        let tipX = 8 + direction.dx * 6
        let tipY = 8 + direction.dy * 6
        for step in 0...6 {
            setPixel(8 + direction.dx * step, 8 + direction.dy * step)
        }
        let wingX = -direction.dy
        let wingY = direction.dx
        for offset in -2...2 {
            setPixel(tipX - direction.dx * 3 + wingX * offset,
                     tipY - direction.dy * 3 + wingY * offset)
        }
        return try MobilePixelFrame(width: width, height: height, rgba: Data(rgba))
    }
}

@MainActor private final class MobileInteractionTestHostController: UIViewController {
    private let game: MobileGameViewController
    private let selection: MobileTargetSelection
    private let control: Int
    private let opensDirectionPicker: Bool
    private let checksAccessibleTargeting: Bool
    private let assignsAccessibly: Bool
    private var presentedPicker = false

    init(game: MobileGameViewController, selection: MobileTargetSelection, control: Int,
         opensDirectionPicker: Bool, checksAccessibleTargeting: Bool, assignsAccessibly: Bool) {
        self.game = game
        self.selection = selection
        self.control = control
        self.opensDirectionPicker = opensDirectionPicker
        self.checksAccessibleTargeting = checksAccessibleTargeting
        self.assignsAccessibly = assignsAccessibly
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(game)
        game.view.frame = view.bounds
        view.addSubview(game.view)
        game.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        game.view.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !presentedPicker else { return }
        presentedPicker = true
        game.resumePlay()
        if opensDirectionPicker {
            _ = game.beginL3ToolDirectionSelection(control: control, target: selection.id, selection: selection)
        } else {
            game.performCommand(.skill(control))
            if checksAccessibleTargeting {
                guard game.moveAccessibleTarget(1) else {
                    preconditionFailure("The L3 accessible target action must select an eligible lemming.")
                }
                let actionNames = Set(game.playfieldView.accessibilityCustomActions?.map(\.name) ?? [])
                guard actionNames.contains("Next eligible lemming"), actionNames.contains("Assign Use") else {
                    preconditionFailure("The L3 playfield must expose target and assignment accessibility actions.")
                }
                if assignsAccessibly && !game.assignAccessibleTarget() {
                    preconditionFailure("The L3 accessible assignment action must start the tool direction picker.")
                }
            }
        }
    }
}
#endif
#endif
