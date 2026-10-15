#if os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit
import GameController

extension MobileGameViewController {
    /// Apply every button edge now. Draw once on the next display frame.
    func processTVControllerButtonEvent(_ process: () -> Void) {
        let wasPolling = pollingController
        pollingController = true
        defer { pollingController = wasPolling }
        process()
    }

    /// Gameplay owns controller buttons. Menus and the L3 picker use native focus.
    func updateTVInputRouting() {
        let usesUIKit = !overlay.isHidden || isChoosingToolDirection || !lifecycle.isForeground
            || lifecycle.isInterrupted || !gameSettings.classic.controllerEnabled || GCController.controllers().isEmpty
        if controllerUserInteractionEnabled != usesUIKit { controllerUserInteractionEnabled = usesUIKit }
    }
    func refreshTVTarget(control: Int) {
        if tvTargetLock.id != nil {
            highlightedTarget = tvTargetLock.resolve(candidates: session.targetCandidates(for: control),
                visible: playfieldView.gameViewport.visibleLevelRect)
        } else { highlightedTarget = previewPoint.flatMap { target(at: $0, control: control) } }
    }
    /// Every touch HUD action also has a focused remote action.
    func showTVControls() {
        pausePlay(showControls: false)
        let snapshot = session.snapshot
        var commands: [(String, () -> Void)] = [
            (L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) }),
            (L10n.text("OVERVIEW"), { [weak self] in
                self?.showOverlay(title: L10n.text("PAUSED"), actions: [
                    (L10n.text("BACK"), { [weak self] in self?.showTVControls() }),
                ])
            }),
            (L10n.text("SETTINGS"), { [weak self] in self?.showInGameSettings() }),
            (L10n.text("CONTROLS HELP"), { [weak self] in self?.onControlsHelp?() }),
            (L10n.text("SKILLS"), { [weak self] in self?.showTVSkills() }),
            (L10n.text("CAMERA"), { [weak self] in self?.showTVCamera() }),
            (L10n.text("NEXT LEMMING"), { [weak self] in self?.tvCommand(.focusUnassigned(1), stayInPlay: true) }),
            (L10n.text("PREVIOUS LEMMING"), { [weak self] in self?.tvCommand(.focusUnassigned(-1), stayInPlay: true) }),
            (L10n.text("LAST ASSIGNMENT"), { [weak self] in self?.tvCommand(.focusLast, stayInPlay: true) }),
            (L10n.text("STEP FORWARD"), { [weak self] in self?.tvCommand(.step(1)) }),
        ]
        if session is Lemmings2MobileSession, !session.isReadOnly {
            commands.insert((fanMode ? L10n.text("SKILL MODE") : L10n.text("FAN"), { [weak self] in
                guard let self else { return }
                self.fanMode.toggle()
                self.resumePlay()
            }), at: 3)
        }
        if session.supportsRewind {
            commands += [
                (L10n.text("STEP BACK"), { [weak self] in self?.tvCommand(.step(-1)) }),
                (L10n.text("REWIND"), { [weak self] in self?.tvCommand(.rewind) }),
            ]
        }
        commands += [
            (L10n.text("SLOWER"), { [weak self] in self?.tvCommand(.speedStep(-1)) }),
            (L10n.text("FASTER"), { [weak self] in self?.tvCommand(.speedStep(1)) }),
        ]
        commands.append((L10n.text("RESUME"), { [weak self] in self?.resumeSelectedView() }))
        if snapshot.releaseRate != nil && !session.isReadOnly {
            commands += [
                (L10n.text("RATE -"), { [weak self] in self?.tvCommand(.rate(-1)) }),
                (L10n.text("RATE +"), { [weak self] in self?.tvCommand(.rate(1)) }),
                (L10n.text("MIN / MAX RATE"), { [weak self] in
                    guard let self else { return }
                    self.tvCommand(.rate(self.session.snapshot.releaseRate == 99 ? -99 : 99))
                }),
            ]
        }
        if !session.isReadOnly {
            commands += [
                (L10n.text("HINT"), { [weak self] in self?.onHints?() }),
                (L10n.text("RESTART LEVEL"), { [weak self] in self?.showRestartLevel() }),
                (snapshot.isEndingRun ? L10n.text("UNDO END RUN") : L10n.text("END RUN"), { [weak self] in self?.showTVEndRun() }),
            ]
        }
        tvPage(title: L10n.text("Game controls"), actions: commands)
    }

    private func showTVSkills() {
        let skills = session.snapshot.skills
        let actions: [(String, () -> Void)] = [(L10n.text("BACK"), { [weak self] in self?.showTVControls() })]
            + skills.enumerated().map { index, skill in
                ("\(skill.name)  \(skill.isUnlimited ? "*" : String(skill.count))", { [weak self] in
                    self?.tvCommand(.skill(index), stayInPlay: true)
                })
            }
        tvPage(title: L10n.text("Skills"), actions: actions)
        for index in skills.indices {
            overlayCanvas.page.rows[index].enabled = !session.isReadOnly && (skills[index].isUnlimited || skills[index].count > 0)
            overlayCanvas.page.rows[index].selected = index == selectedControl
        }
    }

    private func showTVCamera() {
        tvPage(title: L10n.text("Camera"), actions: [
            (L10n.text("BACK"), { [weak self] in self?.showTVControls() }),
            (L10n.text("ZOOM"), { [weak self] in self?.tvCommand(.zoom(false), stayInPlay: true) }),
            (L10n.text("PRECISION"), { [weak self] in self?.tvCommand(.zoom(true), stayInPlay: true) }),
            (L10n.text("ENTRANCE"), { [weak self] in self?.tvCommand(.centre(true), stayInPlay: true) }),
            (L10n.text("EXIT"), { [weak self] in self?.tvCommand(.centre(false), stayInPlay: true) }),
            (L10n.text("MOVE CAMERA"), { [weak self] in self?.tvPlanning(); self?.tvCameraMode = true }),
        ])
    }

    private func showTVEndRun() {
        if session.snapshot.isEndingRun { tvCommand(.endRun); return }
        tvPage(title: L10n.text("End run?"), actions: [
            (L10n.text("CANCEL"), { [weak self] in self?.showTVControls() }),
            (L10n.text("END RUN"), { [weak self] in
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
        let resume = overlayCanvas.page.footer.first { $0.title == L10n.text("RESUME") }
        overlayCanvas.page.rows = Array(overlayCanvas.page.footer.dropFirst()).filter { $0.id != resume?.id }.map {
            .init($0.id, $0.title, enabled: $0.enabled, primary: false)
        }
        overlayCanvas.page.footer = Array(overlayCanvas.page.footer.prefix(1))
        if var resume { resume.primary = true; overlayCanvas.page.footer.append(resume) }
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
