#if os(iOS) || os(tvOS)
import Testing
import UIKit
import LemmingsGameArt
import NxlvKit
@testable import LemmingsMobileUI

@MainActor struct MobileSolutionSelectorTests {
    @Test func presentedRowsKeepTheirRenderedSizeAndPosition() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let selector = MobileSolutionSwitchView(frame: .zero)
        host.addSubview(selector)
        selector.showsGhost = true; selector.isHidden = false
        let region = CGRect(x: 96, y: 54, width: 1728, height: 972)
        let presentation = MobileSolutionSelectorArt.presentation(in: region,
            showsGhost: true, style: MobileSolutionSwitchView.style)
        selector.apply(presentation); selector.layoutIfNeeded()
        #expect(selector.frame == presentation.controls)
        let rows = selector.subviews.compactMap { $0 as? UIButton }
        for (row, logical) in zip(rows, selector.controlLayout.targets) {
            let rendered = row.convert(row.bounds, to: host)
            #expect(rendered.width == logical.width * presentation.scale)
            #expect(rendered.height == logical.height * presentation.scale)
            #expect(presentation.controls.contains(rendered))
            let corner = CGPoint(x: rendered.maxX - 1, y: rendered.maxY - 1)
            let hit = host.hitTest(corner, with: nil)
            #expect(hit === row || hit?.isDescendant(of: row) == true)
        }
    }

    @Test func nativeTargetsMatchTheBitmapRowsAndGhostState() {
        let selector = MobileSolutionSwitchView(frame: CGRect(x: 0, y: 0, width: 304, height: 168))
        selector.showsGhost = true; selector.isHidden = false; selector.layoutIfNeeded()
        let rows = selector.subviews.compactMap { $0 as? UIButton }
        #expect(rows.count == 3)
        for (row, frame) in zip(rows, selector.controlLayout.targets) {
            #expect(row.frame == frame)
            #expect(frame.height >= 44)
            for point in [CGPoint(x: frame.minX + 1, y: frame.minY + 1), CGPoint(x: frame.maxX - 1, y: frame.maxY - 1)] {
                let hit = selector.hitTest(point, with: nil)
                #expect(hit === row || hit?.isDescendant(of: row) == true)
            }
        }
        #expect(rows[2].frame.width == selector.bounds.width)
        #expect(rows[2].accessibilityValue == L10n.text("Off"))
        var presses = 0
        selector.onToggleGhost = { presses += 1; selector.ghostEnabled.toggle() }
        selector.observeNeutral()
        rows[2].sendActions(for: .gameActivation)
        #expect(presses == 1 && selector.ghostEnabled)
        #expect(rows[2].accessibilityValue == L10n.text("On"))
        #expect(rows[2].accessibilityTraits.contains(.selected))
        selector.isHidden = true
        rows[2].sendActions(for: .gameActivation)
        #expect(presses == 1)
    }

    @Test func unavailableGhostAndHeldActivationCannotLeakToAnotherView() {
        let selector = MobileSolutionSwitchView(frame: .zero)
        selector.isHidden = false
        var ghosts = 0, switches = 0
        selector.onToggleGhost = { ghosts += 1 }
        selector.onSelect = { _ in switches += 1 }
        selector.showsGhost = false; selector.focusedIndex = 2
        selector.activateGhost()
        #expect(ghosts == 0)
        selector.showsGhost = true
        selector.resetActivation()
        #if os(tvOS)
        selector.activateGhost()
        #expect(ghosts == 0)
        selector.observeNeutral(); selector.activateGhost(); selector.activateGhost()
        #expect(ghosts == 1)
        selector.activate(.solution)
        #expect(switches == 0)
        #endif
        selector.observeNeutral(); selector.activate(.solution)
        #expect(switches == 1)
        selector.isHidden = true
        selector.observeNeutral(); selector.activate(.game)
        #expect(switches == 1)
    }

    #if os(tvOS)
    @Test func televisionFocusUsesTheVisibleFullWidthRows() {
        let selector = MobileSolutionSwitchView(frame: CGRect(x: 0, y: 0, width: 480, height: 168))
        selector.showsGhost = true; selector.isHidden = false; selector.layoutIfNeeded()
        let rows = selector.subviews.compactMap { $0 as? UIButton }
        #expect(rows.allSatisfy { $0.frame.width == selector.bounds.width })
        for index in rows.indices {
            selector.focusedIndex = index
            #expect(selector.preferredFocusEnvironments.first === rows[index])
        }
        selector.showsGhost = false
        #expect(selector.focusedIndex != 2)
        #expect(rows[2].isHidden)
        selector.isHidden = true
        #expect(selector.preferredFocusEnvironments.isEmpty)
    }
    #endif
}
#endif
