#if os(iOS)
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileGameViewController {
    func showHints(stage: Int = 0) {
        pauseForPlanning()
        let catalogue = LevelHintCatalogue.load()
        let fingerprint = (session as? ClassicMobileSession).map { TrolleyCapture.classicFingerprint($0.initialSimulation) } ?? ""
        let deck = catalogue.flatMap { $0.0.level(for: fingerprint, engine: $0.1)?.deck }
            ?? .practice(title: summary.title, skills: session.snapshot.skills.filter { $0.count != 0 }.map(\.name))
        let index = min(max(0, stage), deck.stages.count - 1)
        let hint = deck.stages[index]
        var actions: [(String, () -> Void)] = []
        if index > 0 { actions.append(("PREVIOUS", { [weak self] in self?.showHints(stage: index - 1) })) }
        if index + 1 < deck.stages.count { actions.append(("NEXT HINT", { [weak self] in self?.showHints(stage: index + 1) })) }
        if let classic = session as? ClassicMobileSession,
           let solution = VerifiedSolution.load(initial: classic.initialSimulation, from: Bundle.main.resourceURL) {
            actions.append(("WATCH SOLUTION", { [weak self] in
                self?.showCustomOverlay(title: "Watch solution?", details: [], actions: [
                    ("CANCEL", { [weak self] in self?.showHints(stage: index) }),
                    ("WATCH", { [weak self] in
                        guard let data = try? JSONEncoder().encode(solution.replay) else { return }
                        self?.showReplay(document: data)
                    })])
            }))
        }
        actions.append(("BACK", { [weak self] in self?.pausePlay(showControls: true) }))
        let width = max(24, min(68, Int(view.bounds.width / 8) - 10))
        showCustomOverlay(title: hint.title, details: Self.wrapHint(hint.body, columns: width), actions: actions)
    }

    static func wrapHint(_ text: String, columns: Int) -> [String] {
        var result: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            var line = ""
            for word in paragraph.split(separator: " ") {
                if !line.isEmpty, line.count + word.count + 1 > columns { result.append(line); line = "" }
                line += (line.isEmpty ? "" : " ") + word
            }
            result.append(line)
        }
        return result
    }
}
#endif
