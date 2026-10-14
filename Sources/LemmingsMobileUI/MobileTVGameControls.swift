#if os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileGameViewController {
    /// Every touch HUD action also has a focused remote action.
    func showTVControls() {
        pausePlay(showControls: false)
        let snapshot = session.snapshot
        var commands: [(String, () -> Void)] = [
            ("BACK", { [weak self] in self?.pausePlay(showControls: true) }),
            ("OVERVIEW", { [weak self] in
                self?.showOverlay(title: "PAUSED", actions: [
                    ("BACK", { [weak self] in self?.showTVControls() }),
                ])
            }),
            ("SETTINGS", { [weak self] in self?.showInGameSettings() }),
            ("CONTROLS HELP", { [weak self] in self?.onControlsHelp?() }),
            ("SKILLS", { [weak self] in self?.showTVSkills() }),
            ("CAMERA", { [weak self] in self?.showTVCamera() }),
            ("NEXT LEMMING", { [weak self] in self?.tvCommand(.focusUnassigned(1), stayInPlay: true) }),
            ("PREVIOUS LEMMING", { [weak self] in self?.tvCommand(.focusUnassigned(-1), stayInPlay: true) }),
            ("LAST ASSIGNMENT", { [weak self] in self?.tvCommand(.focusLast, stayInPlay: true) }),
            ("STEP FORWARD", { [weak self] in self?.tvCommand(.step(1)) }),
        ]
        if session is Lemmings2MobileSession, !session.isReadOnly {
            commands.insert((fanMode ? "SKILL MODE" : "FAN", { [weak self] in
                guard let self else { return }
                self.fanMode.toggle()
                self.resumePlay()
            }), at: 3)
        }
        if session.supportsRewind {
            commands += [
                ("STEP BACK", { [weak self] in self?.tvCommand(.step(-1)) }),
                ("REWIND", { [weak self] in self?.tvCommand(.rewind) }),
            ]
        }
        commands += [
            ("SLOWER", { [weak self] in self?.tvCommand(.speedStep(-1)) }),
            ("FASTER", { [weak self] in self?.tvCommand(.speedStep(1)) }),
        ]
        if snapshot.releaseRate != nil && !session.isReadOnly {
            commands += [
                ("RATE -", { [weak self] in self?.tvCommand(.rate(-1)) }),
                ("RATE +", { [weak self] in self?.tvCommand(.rate(1)) }),
                ("MIN / MAX RATE", { [weak self] in
                    guard let self else { return }
                    self.tvCommand(.rate(self.session.snapshot.releaseRate == 99 ? -99 : 99))
                }),
            ]
        }
        if !session.isReadOnly {
            commands += [
                ("HINT", { [weak self] in self?.onHints?() }),
                ("RESTART LEVEL", { [weak self] in self?.showRestartLevel() }),
                (snapshot.isEndingRun ? "UNDO END RUN" : "END RUN", { [weak self] in self?.showTVEndRun() }),
            ]
        }
        tvPage(title: "Game controls", actions: commands)
    }

    private func showTVSkills() {
        let skills = session.snapshot.skills
        let actions: [(String, () -> Void)] = [("BACK", { [weak self] in self?.showTVControls() })]
            + skills.enumerated().map { index, skill in
                ("\(skill.name)  \(skill.isUnlimited ? "*" : String(skill.count))", { [weak self] in
                    self?.tvCommand(.skill(index), stayInPlay: true)
                })
            }
        tvPage(title: "Skills", actions: actions)
        for index in skills.indices {
            overlayCanvas.page.rows[index].enabled = !session.isReadOnly && (skills[index].isUnlimited || skills[index].count > 0)
            overlayCanvas.page.rows[index].selected = index == selectedControl
        }
    }

    private func showTVCamera() {
        tvPage(title: "Camera", actions: [
            ("BACK", { [weak self] in self?.showTVControls() }),
            ("ZOOM", { [weak self] in self?.tvCommand(.zoom(false), stayInPlay: true) }),
            ("PRECISION", { [weak self] in self?.tvCommand(.zoom(true), stayInPlay: true) }),
            ("ENTRANCE", { [weak self] in self?.tvCommand(.centre(true), stayInPlay: true) }),
            ("EXIT", { [weak self] in self?.tvCommand(.centre(false), stayInPlay: true) }),
            ("MOVE CAMERA", { [weak self] in self?.tvPlanning(); self?.tvCameraMode = true }),
        ])
    }

    private func showTVEndRun() {
        if session.snapshot.isEndingRun { tvCommand(.endRun); return }
        tvPage(title: "End run?", actions: [
            ("CANCEL", { [weak self] in self?.showTVControls() }),
            ("END RUN", { [weak self] in
                guard let self, self.tvPlanning() else { return }
                _ = self.session.beginEndRun()
                self.renderCurrentFrame(force: true)
                self.pausePlay(showControls: true)
            }),
        ])
    }

    private func tvPage(title: String, actions: [(String, () -> Void)]) {
        showCustomOverlay(title: title, details: [], actions: actions)
        // Shared pages scroll their rows; the primary forward action remains in the footer.
        overlayCanvas.page.rows = Array(overlayCanvas.page.footer.dropFirst()).map {
            .init($0.id, $0.title, enabled: $0.enabled, primary: false)
        }
        overlayCanvas.page.footer = Array(overlayCanvas.page.footer.prefix(1))
        view.setNeedsLayout()
        view.layoutIfNeeded()
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    @discardableResult private func tvPlanning() -> Bool {
        guard lifecycle.isForeground, !lifecycle.isInterrupted, !session.snapshot.isComplete else { return false }
        guard playState.resume(isForeground: true, isInterrupted: false), playState.pauseForPlanning() else { return false }
        overlay.isHidden = true
        overlay.accessibilityViewIsModal = false
        playfieldView.accessibilityElementsHidden = false
        hud.accessibilityElementsHidden = false
        playfieldView.isUserInteractionEnabled = true
        hud.isUserInteractionEnabled = true
        clock.suspend()
        inputAdapter.reset()
        updateHUD()
        return true
    }

    private func tvCommand(_ command: GameplayCommand, stayInPlay: Bool = false) {
        guard tvPlanning() else { return }
        performCommand(command)
        if !stayInPlay && !session.snapshot.isComplete { showTVControls() }
    }
}
#endif
