#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit

actor MobileTeachingLoader {
    static let shared = MobileTeachingLoader()
    private var catalogue: (LevelHintCatalogue, String)?
    private var results: [String: (LevelHintDeck, VerifiedSolution?)] = [:]
    func load(initial: ClassicDOSSimulation?, title: String, skills: [String]) -> (LevelHintDeck, VerifiedSolution?) {
        let fingerprint = initial.map { TrolleyCapture.classicFingerprint($0) } ?? title
        if let cached = results[fingerprint] { return cached }
        if catalogue == nil { catalogue = LevelHintCatalogue.load() }
        let deck = catalogue.flatMap { $0.0.level(for: fingerprint, engine: $0.1)?.deck }
            ?? .practice(title: title, skills: skills)
        let solution = initial.flatMap { VerifiedSolution.load(initial: $0, from: Bundle.main.resourceURL) }
        if results.count > 32 { results.removeAll() }
        results[fingerprint] = (deck, solution)
        return (deck, solution)
    }
}

extension MobileGameViewController {
    func showHints(stage: Int = 0) {
        guard !session.isReadOnly else { pausePlay(showControls: true); return }
        pauseForPlanning()
        showCustomOverlay(title: L10n.text("Hints"), details: [L10n.text("Loading...")], actions: [(L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) })])
        let request = UUID(); hintRequestID = request
        let initial = (session as? ClassicMobileSession)?.initialSimulation
        let title = summary.title, skills = session.snapshot.skills.filter { $0.count != 0 }.map(\.name)
        Task { [weak self] in
            let (deck, solution) = await MobileTeachingLoader.shared.load(initial: initial, title: title, skills: skills)
            guard let self, self.hintRequestID == request, self.paused else { return }
            self.presentHints(deck: deck, solution: solution, stage: stage)
        }
    }

    private func presentHints(deck: LevelHintDeck, solution: VerifiedSolution?, stage: Int) {
        let index = min(max(0, stage), deck.stages.count - 1)
        let hint = deck.stages[index]
        var actions: [(String, () -> Void)] = []
        if index > 0 { actions.append((L10n.text("PREVIOUS"), { [weak self] in self?.showHints(stage: index - 1) })) }
        if index + 1 < deck.stages.count { actions.append((L10n.text("NEXT HINT"), { [weak self] in self?.showHints(stage: index + 1) })) }
        if let solution {
            actions.append((L10n.text("WATCH SOLUTION"), { [weak self] in
                if self?.hasSolutionPair == true { self?.selectSolutionMode(.solution); return }
                self?.confirmSolution(solution, stage: index, title: L10n.text("Watch solution?"),
                                      confirm: L10n.text("WATCH"), ghostOnly: false)
            }))
            // The ghost replays the verified solution behind the live lemmings without leaving the attempt.
            if session is ClassicMobileSession {
                actions.append((L10n.text("GHOST SOLUTION"), { [weak self] in
                    if self?.hasSolutionPair == true { self?.showGhostSolution(); return }
                    self?.confirmSolution(solution, stage: index, title: L10n.text("Show ghost solution?"),
                                          confirm: L10n.text("SHOW"), ghostOnly: true)
                }))
            }
        }
        actions.append((L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) }))
        let width = max(24, min(68, Int(view.bounds.width / 8) - 10))
        showCustomOverlay(title: hint.title, details: Self.wrapHint(hint.body, columns: width), actions: actions)
    }

    /// Both reveals keep the spoiler confirmation, with Cancel returning to the same hint.
    private func confirmSolution(_ solution: VerifiedSolution, stage: Int, title: String, confirm: String, ghostOnly: Bool) {
        showCustomOverlay(title: title, details: [], actions: [
            (L10n.text("CANCEL"), { [weak self] in self?.showHints(stage: stage) }),
            (confirm, { [weak self] in
                guard let data = try? JSONEncoder().encode(solution.replay) else { return }
                self?.showReplay(document: data, solution: true, ghostOnly: ghostOnly)
            })])
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
