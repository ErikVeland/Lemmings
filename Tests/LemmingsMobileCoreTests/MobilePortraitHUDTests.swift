import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobilePortraitHUDTests {
    @Test func releaseRateDoubleTapReplacesSecondStepAndDoesNotRepeat() {
        var press = MobileHUDPress(.releaseRate)
        let first = press.begin(at: 0)
        #expect(first == [.activate])
        _ = press.end(at: 0.05)
        let second = press.begin(at: 0.15)
        #expect(second == [.doubleTap])
        let held = press.update(at: 0.8)
        #expect(held.isEmpty)
        _ = press.end(at: 0.9)
        let next = press.begin(at: 1)
        #expect(next == [.activate])
        _ = press.end(at: 1.05)
        let again = press.begin(at: 1.15)
        #expect(again == [.doubleTap])
    }

    @Test func releaseRateHoldAndCancellationDoNotBecomeDoubleTaps() {
        var press = MobileHUDPress(.releaseRate)
        _ = press.begin(at: 0)
        let repeated = press.update(at: 0.4)
        #expect(repeated == [.activate])
        _ = press.end(at: 0.45)
        let afterHold = press.begin(at: 0.5)
        #expect(afterHold == [.activate])
        _ = press.end(at: 0.55, cancelled: true)
        let afterCancel = press.begin(at: 0.6)
        #expect(afterCancel == [.activate])
    }

    @Test func originalIPadProKeepsTouchDeckOnRotation() throws {
        for size in [MobileSize(width: 768, height: 1024), .init(width: 1024, height: 1366)] {
            let portrait = MobileHUDLayout.make(container: size, safeArea: .init(top: 20),
                hasRate: true, skillCount: 8, supportsRewind: true)
            #expect(portrait.portrait != nil)
            #expect(portrait.interface.controlsFrame.height == 176)
            #expect(portrait.interface.playfieldFrame.height == size.height - 240)
            let landscape = MobileHUDLayout.make(container: .init(width: size.height, height: size.width),
                safeArea: .init(top: 20), hasRate: true, skillCount: 8, supportsRewind: true)
            #expect(landscape.portrait != nil)
            #expect(landscape.canPlay)
        }
    }

    @Test func safeAreaAndPlayfieldOcclusionsKeepPortraitControls() throws {
        for region in [MobileReservedRegion(kind: .occlusion, frame: .init(x: 160, y: 0, width: 70, height: 40)),
                       .init(kind: .occlusion, frame: .init(x: 0, y: 200, width: 20, height: 100)),
                       .init(kind: .division, frame: .init(x: 0, y: -20, width: 390, height: 20))] {
            let layout = MobileHUDLayout.make(container: .init(width: 390, height: 844),
                safeArea: .init(top: 47, bottom: 34), hasRate: true, skillCount: 8,
                reservedRegions: [region], supportsRewind: true)
            #expect(layout.portrait != nil)
            #expect(layout.interface.controlsFrame.height == 176)
            // UIKit must still block playfield input in the system region.
            #expect(layout.reservedRegions == [region])
        }
    }

    @Test func obstructedPortraitControlsUseAdaptiveFallback() {
        for region in [MobileReservedRegion(kind: .occlusion, frame: .init(x: 0, y: 750, width: 30, height: 30)),
                       .init(kind: .division, frame: .init(x: 0, y: 420, width: 390, height: 20)),
                       .init(kind: .occlusion, frame: .init(x: 335, y: 54, width: 50, height: 50)),
                       .init(kind: .occlusion, frame: .init(x: 245, y: 640, width: 44, height: 44))] {
            let layout = MobileHUDLayout.make(container: .init(width: 390, height: 844),
                safeArea: .init(top: 47, bottom: 34), hasRate: true, skillCount: 8,
                reservedRegions: [region], supportsRewind: true)
            if region.kind != .division { #expect(layout.portrait == nil) }
            #expect(layout.canPlay)
            #expect(layout.interface.controlFrames.allSatisfy { !$0.intersects(region.frame) })
        }
    }

    @Test func twoRowsKeepHeightAndMapAcrossEngines() throws {
        for width in [320.0, 390, 834, 1024] {
            for (rate, skills) in [(true, 8), (false, 8), (false, 5), (true, 21)] {
                let layout = MobileHUDLayout.make(container: .init(width: width, height: 1366),
                    safeArea: .init(top: 47, bottom: 34), hasRate: rate, skillCount: skills, supportsRewind: true)
                let portrait = try #require(layout.portrait)
                #expect(layout.interface.controlsFrame.height == 176)
                #expect(layout.interface.playfieldFrame.height == 1065)
                let offset = rate ? 2 : 0
                let skillFrames = Array(layout.interface.controlFrames[offset..<(offset + skills)])
                #expect(skillFrames.allSatisfy { $0.y == portrait.skills.minY && $0.width >= 44 })
                let transport = layout.interface.controlFrames
                let pause = transport[offset + skills], nuke = transport[offset + skills + 1]
                let speed = transport[offset + skills + 2], rewind = transport[offset + skills + 3]
                #expect(speed.maxX < nuke.minX && nuke.maxX < pause.minX)
                #expect([pause, nuke, speed].allSatisfy { $0.y == pause.y && $0.width >= 44 })
                #expect(rewind.y == portrait.minimap.minY && rewind.height == portrait.minimap.height)
                #expect(rewind.minX == layout.interface.safeFrame.minX)
                #expect(transport[offset + skills + 5].maxX < portrait.minimap.minX)
                #expect(pause.maxX == layout.interface.safeFrame.maxX)
                #expect(abs(Double(portrait.minimap.maxX) - layout.interface.safeFrame.maxX) < 0.001)
                #expect(portrait.minimap.maxY < portrait.skills.minY)
                let lastSkill = try #require(skillFrames.last)
                let scrollOffset = max(0, portrait.skillContentWidth - portrait.skills.width)
                #expect(lastSkill.maxX - scrollOffset <= portrait.skills.maxX + 0.001)
                #expect(lastSkill.minX - scrollOffset >= portrait.skills.minX)
            }
        }
    }

    @Test func rateRepeatsAndStopsOnCancel() {
        var press = MobileHUDPress(.rate)
        #expect(press.begin(at: 0) == [.activate])
        #expect(press.update(at: 0.34).isEmpty)
        #expect(press.update(at: 0.35) == [.activate])
        #expect(press.update(at: 0.43) == [.activate])
        #expect(press.end(at: 0.44, cancelled: true).isEmpty)
        #expect(press.update(at: 2).isEmpty)
    }

    @Test func heldRewindStopsOnceAndCannotBecomeATap() {
        var press = MobileHUDPress(.rewind)
        #expect(press.begin(at: 0) == [.pedal(true, allowTap: false)])
        #expect(press.begin(at: 0.01).isEmpty)
        #expect(press.update(at: 1).isEmpty)
        #expect(press.end(at: 1, cancelled: true) == [.pedal(false, allowTap: false)])
        #expect(press.end(at: 2).isEmpty)
    }

    @Test func shortPortraitKeepsNavigationAndMenuApart() throws {
        let layout = MobileHUDLayout.make(container: .init(width: 320, height: 348),
            safeArea: .init(top: 20, bottom: 20), hasRate: true, skillCount: 8, supportsRewind: true)
        let portrait = try #require(layout.portrait)
        let menu = try #require(layout.interface.controlFrames.last)
        #expect(layout.interface.playfieldFrame.minY >= menu.maxY)
        #expect(abs(Double(portrait.minimap.minY) - layout.interface.playfieldFrame.maxY) < 0.001)
        #expect(portrait.minimap.maxY < portrait.skills.minY)
        #expect(layout.canPlay)
        let tooShort = MobileHUDLayout.make(container: .init(width: 320, height: 310),
            safeArea: .init(top: 20, bottom: 20), hasRate: true, skillCount: 8, supportsRewind: true)
        #expect(!tooShort.canPlay)
    }

    @Test func phoneLandscapeKeepsTheSameControlsAndSafeEdges() throws {
        let layout = MobileHUDLayout.make(container: .init(width: 844, height: 390),
            safeArea: .init(left: 47, bottom: 21, right: 47), hasRate: true, skillCount: 8, supportsRewind: true)
        let deck = try #require(layout.portrait)
        #expect(layout.interface.orientation == .landscape)
        #expect(layout.canPlay)
        #expect(deck.skills.minX == 47 && deck.skills.maxX < 797)
        #expect(layout.interface.controlsFrame.height == 126)
        #expect(layout.interface.playfieldFrame.height == 199)
        let controls = layout.interface.controlFrames
        #expect(abs(controls[0].y - Double(deck.skills.minY)) < 0.001)
        #expect(abs(controls[10].y - Double(deck.skills.minY)) < 0.001)
        #expect(deck.minimap.maxX == 797)
        #expect(layout.interface.controlFrames.last?.maxX == 797)
    }

    @Test func pauseAndNukeHoldNeverAlsoTap() {
        for kind in [MobileHUDPress.Kind.pause, .nuke] {
            var press = MobileHUDPress(kind)
            #expect(press.begin(at: 0).isEmpty)
            #expect(press.end(at: 0.1) == [.activate])
            _ = press.begin(at: 1)
            #expect(press.update(at: 1.61) == [.hold])
            #expect(press.update(at: 2).isEmpty)
            #expect(press.end(at: 2).isEmpty)
            _ = press.begin(at: 3)
            #expect(press.end(at: 4) == [.hold])
            _ = press.begin(at: 5)
            #expect(press.end(at: 6, cancelled: true).isEmpty)
        }
    }

    @Test func speedTouchHoldKeepsReachedTierAndNextTapResets() {
        for variable in [true, false] {
            var speed = GameplaySpeed()
            speed.variableEnabled = variable
            var press = MobileHUDPress(.speed)
            func deliver(_ effects: [MobileHUDPress.Effect], at time: Double) {
                for effect in effects {
                    switch effect {
                    case .activate: speed.tap(at: time)
                    case let .pedal(held, allowTap):
                        if held { speed.press(.mouse, at: time) }
                        else { speed.release(.mouse, at: time, allowTap: allowTap, retainReachedSpeed: allowTap) }
                    case .hold, .doubleTap: break
                    }
                }
            }
            deliver(press.begin(at: 0), at: 0)
            deliver(press.end(at: 0.1), at: 0.1)
            #expect(speed.target == (variable ? 2 : 3))
            deliver(press.begin(at: 1), at: 1)
            speed.update(at: 2)
            #expect(speed.target > 1)
            let reached = speed.target
            deliver(press.end(at: 2), at: 2)
            #expect(speed.target == reached)
            deliver(press.begin(at: 3), at: 3)
            deliver(press.end(at: 3.1, cancelled: true), at: 3.1)
            #expect(!speed.isHeld && speed.target == reached)
            deliver(press.begin(at: 4), at: 4)
            deliver(press.end(at: 4.1), at: 4.1)
            #expect(speed.target == 1)
        }
    }
}
