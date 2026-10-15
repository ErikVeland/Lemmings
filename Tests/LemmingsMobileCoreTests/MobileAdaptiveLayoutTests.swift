import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileAdaptiveLayoutTests {
    @Test func controlDeckAvoidsSystemRegionsAcrossEngineControlSets() {
        let poses: [(MobileSize, [MobileReservedRegion])] = [
            (.init(width: 390, height: 844), []),
            (.init(width: 834, height: 1112), []),
            (.init(width: 1112, height: 834), []),
            (.init(width: 330, height: 460), []),
            (.init(width: 650, height: 465), []),
            (.init(width: 650, height: 465), [
                .init(kind: .division, frame: .init(x: 318, y: 0, width: 14, height: 465)),
                .init(kind: .occlusion, frame: .init(x: 600, y: 415, width: 50, height: 50)),
            ]),
            (.init(width: 1194, height: 834), [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            (.init(width: 1194, height: 834), [.init(kind: .division, frame: .init(x: 0, y: 405, width: 1194, height: 24))]),
            (.init(width: 1194, height: 834), [
                .init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
                .init(kind: .occlusion, frame: .init(x: 1120, y: 740, width: 74, height: 94)),
            ]),
            (.init(width: 568, height: 320), []),
            (.init(width: 320, height: 568), []),
        ]
        // Classic, L2's eight native skill slots and L3's five native actions.
        for (rate, skills) in [(true, 8), (false, 8), (false, 5), (false, 21)] {
            for (size, regions) in poses {
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                                                  hasRate: rate, skillCount: skills, reservedRegions: regions)
                if !layout.canPlay {
                    #expect(layout.interface.controlFrames.isEmpty)
                    continue
                }
                #expect(layout.interface.controlFrames.count == (rate ? 2 : 0) + skills + 5)
                let safe = layout.interface.safeFrame
                for (index, frame) in (layout.interface.controlFrames + [layout.interface.statusFrame]).enumerated() {
                    let firstSkill = rate ? 2 : 0
                    if let portrait = layout.portrait, (firstSkill..<(firstSkill + skills)).contains(index) {
                        #expect(frame.minX >= portrait.skills.minX)
                        #expect(frame.maxX <= portrait.skills.minX + portrait.skillContentWidth + 0.001)
                        #expect(abs(frame.minY - Double(portrait.skills.minY)) < 0.001)
                        continue
                    }
                    #expect(safe.contains(.init(x: frame.minX, y: frame.minY)))
                    #expect(safe.contains(.init(x: frame.maxX, y: frame.maxY)))
                    #expect(regions.allSatisfy { !frame.intersects($0.frame) })
                }
                for frame in layout.interface.controlFrames {
                    #expect(frame.width >= 44 && frame.height >= 44)
                }
                for arrow in layout.speedArrows { #expect(arrow.width >= 44 && arrow.height >= 44) }
                if layout.isDiorama {
                    #expect(layout.interface.playfieldFrame.maxY <= 405)
                    #expect(layout.interface.controlsFrame.minY >= 429)
                }
            }
        }
    }

    @Test func wideIPadUsesTouchDeckAndTinyViewsSuspend() {
        let wide = MobileHUDLayout.make(container: .init(width: 1112, height: 834),
                                        safeArea: .init(top: 20, bottom: 20), hasRate: true, skillCount: 8)
        #expect(wide.portrait != nil)
        #expect(wide.interface.controlsFrame.width == 1112)
        #expect(wide.interface.controlFrames[13].height == 44)
        let tiny = MobileHUDLayout.make(container: .init(width: 280, height: 160), safeArea: .init(), hasRate: true, skillCount: 8)
        #expect(!tiny.canPlay)
        #expect(tiny.interface.controlFrames.isEmpty)
    }

    @Test func lemmings3KeepsItsNativePanelAndTouchTargetsOnWideScreens() {
        let layout = MobileHUDLayout.make(
            container: .init(width: 1112, height: 834),
            safeArea: .init(top: 20, bottom: 20),
            hasRate: false,
            skillCount: 5,
            supportsRewind: true,
            engineIdentifier: "lemmings3"
        )

        #expect(layout.canPlay)
        #expect(layout.panel?.style == .lemmings3)
        #expect(layout.panel?.scale == 3)
        #expect(layout.minimapFrame == nil)
        #expect(layout.interface.controlFrames.count == 12)
        #expect(layout.interface.playfieldFrame.height >= 88)
        #expect(layout.interface.controlFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        #expect(layout.reservedRegions.allSatisfy { region in
            layout.interface.controlFrames.allSatisfy { !$0.intersects(region.frame) }
        })
    }

    @Test func lemmings3UsesAdaptiveControlsWhenTheNativePanelCannotFit() {
        let layout = MobileHUDLayout.make(
            container: .init(width: 1194, height: 834),
            safeArea: .init(top: 20, bottom: 20),
            hasRate: false,
            skillCount: 5,
            reservedRegions: [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))],
            engineIdentifier: "lemmings3"
        )

        #expect(layout.canPlay)
        #expect(layout.panel == nil)
        #expect(layout.interface.controlFrames.count == 10)
        #expect(layout.interface.controlFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        #expect(layout.interface.controlFrames.allSatisfy { !$0.intersects(.init(x: 589, y: 0, width: 16, height: 834)) })
    }

    @Test func mobileAndTVKeepStatusInOneRowAboveAllThreeGames() {
        let poses = [MobileSize(width: 320, height: 568), .init(width: 844, height: 390),
                     .init(width: 768, height: 1024), .init(width: 1920, height: 1080)]
        for size in poses {
            for (engine, rate, skills) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                for television in [false, true] {
                    let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                        hasRate: rate, skillCount: skills, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: engine, showsMenuButton: !television, television: television)
                    let status = layout.interface.statusFrame
                    #expect(layout.canPlay)
                    #expect(status.minY == layout.interface.safeFrame.minY)
                    #expect(status.height == 44)
                    #expect(status.maxY == layout.interface.playfieldFrame.minY)
                    #expect(layout.interface.controlFrames.allSatisfy { !$0.intersects(status) })
                }
            }
        }
    }

    @Test func menusStayClearOfDivisionAndOcclusionWhileScrolling() {
        let safe = MobileRect(x: 20, y: 24, width: 1154, height: 790)
        let regions: [MobileReservedRegion] = [
            .init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
            .init(kind: .occlusion, frame: .init(x: 1120, y: 24, width: 74, height: 60)),
        ]
        let menu = MobileDisplayRegions.menuFrame(in: safe, avoiding: regions)
        #expect(menu.width >= 280)
        #expect(regions.allSatisfy { !menu.intersects($0.frame) })
        #expect(safe.contains(.init(x: menu.minX, y: menu.minY)))
        #expect(safe.contains(.init(x: menu.maxX, y: menu.maxY)))
    }

    @Test func unfoldingRevealsTerrainWithoutChangingZoomOrCameraCentre() {
        for aspect in [1.0, 1.2] {
            var viewport = MobileViewport(levelSize: .init(width: 1600, height: 160),
                                          viewSize: .init(width: 390, height: 300),
                                          origin: .init(x: 600, y: 0), zoom: 2, pixelAspect: aspect)
            let centre = viewport.origin.x + viewport.visibleLevelSize.width / 2
            let before = viewport.visibleLevelSize.width
            viewport.resize(.init(width: 1112, height: 600))
            #expect(viewport.zoom == 2)
            #expect(viewport.visibleLevelSize.width > before)
            #expect(abs(viewport.origin.x + viewport.visibleLevelSize.width / 2 - centre) < 0.001)
            viewport.resize(.init(width: 390, height: 300))
            #expect(abs(viewport.origin.x - 600) < 0.001)
        }
    }
}
