#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsMobileCore
import UIKit

extension MobileLibraryViewController {
    func makeLibraryInput() -> MobileInputAdapter {
        let adapter = MobileInputAdapter()
        adapter.settings = { [weak self] in self?.mobileSettings.classic ?? MobileSettings().classic }
        adapter.settingsProfileID = { [weak self] in self?.settingsProfileID ?? MobileProfiles.defaultID }
        #if os(tvOS)
        canvas.requiresNeutralActivation = true
        #endif
        adapter.isMenu = { true }
        adapter.isActive = { [weak self] in
            guard let self else { return false }
            return !self.deskClockBlocksInput && self.game == nil && !self.searchField.isFirstResponder && self.mobileInsights.field?.isFirstResponder != true && self.view.window?.windowScene?.activationState == .foregroundActive
        }
        adapter.onMenuMove = { [weak self] delta in
            guard let self else { return }
            #if os(iOS)
            self.deskClockEntry.noteInput()
            #endif
            if self.browserShown { self.selectLevel(max(0, min((self.library?.levels.count ?? 1) - 1, self.selectedIndex + delta))) }
            else { self.canvas.moveFocus(delta) }
        }
        adapter.onMenuActivate = { [weak self] in
            guard let self else { return }
            #if os(iOS)
            self.deskClockEntry.noteInput()
            #endif
            if self.browserShown { self.startLevel(self.selectedIndex, checkpoint: nil) }
            else { self.canvas.activateFocused() }
        }
        canvas.onPageChanged = { [weak adapter] in adapter?.reset() }
        adapter.onMenuScroll = { [weak self] delta in
            guard let self else { return }
            #if os(iOS)
            self.deskClockEntry.noteInput()
            #endif
            self.canvas.scrollInput(delta: delta)
        }
        adapter.onMenuBack = { [weak self] in
            guard let self else { return }
            #if os(iOS)
            self.deskClockEntry.noteInput()
            #endif
            if self.browserShown { self.navigate(self.levelsBackRoute) }
            else { self.canvas.goBack() }
        }
        return adapter
    }
    @objc func pollLibraryInput(_ link: CADisplayLink) {
        guard !deskClockBlocksInput, game == nil, view.window?.windowScene?.activationState == .foregroundActive else { return }
        libraryInput.poll(context: ObjectIdentifier(canvas), at: link.timestamp)
        advanceHomeBackdrop(at: link.timestamp)
    }
}
#endif
