import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileAdaptiveLayoutTests {
    @Test func rotatedFrontCamerasClearEveryFixedControlAcrossNativeEngines() {
        for size in [MobileSize(width: 495, height: 720), .init(width: 720, height: 495)] {
            for leading in [false, true] {
                for top in [false, true] {
                    let camera = MobileReservedRegion(kind: .occlusion, frame: .init(
                        x: leading ? 0 : size.width - 92, y: top ? 0 : size.height - 80, width: 92, height: 80))
                    for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                        let layout = MobileHUDLayout.make(container: size, safeArea: .init(), hasRate: rate,
                            skillCount: count, reservedRegions: [camera], supportsRewind: true,
                            engineIdentifier: engine, fillsDisplayWidth: true)
                        #expect(layout.canPlay)
                        #expect(layout.interface.playfieldFrame.minX == 0 && layout.interface.playfieldFrame.maxX == size.width)
                        #expect(!layout.interface.statusFrame.intersects(camera.frame))
                        #expect(layout.interface.controlFrames.allSatisfy { !$0.intersects(camera.frame) })
                        if let map = layout.minimapFrame {
                            #expect(!MobileRect(x: map.minX, y: map.minY, width: map.width, height: map.height).intersects(camera.frame))
                        }
                        let start = rate ? 2 : 0
                        let skills = Array(layout.interface.controlFrames[start..<(start + count)])
                        #expect(Set(skills.map(\.minY)).count == 1)
                    }
                }
            }
        }
    }

    @Test func partialFoldsKeepNativeSkillsInOneRowAcrossHingeWidthsAndBothAxes() throws {
        for size in [MobileSize(width: 1194, height: 834), .init(width: 834, height: 1194),
                     .init(width: 650, height: 465), .init(width: 465, height: 650)] {
            for vertical in [false, true] {
                for width in [0.5, 1, 8, 16, 40] {
                    let hinge = MobileReservedRegion(kind: .division, frame: vertical
                        ? .init(x: size.width / 2 - width / 2, y: 0, width: width, height: size.height)
                        : .init(x: 0, y: size.height / 2 - width / 2, width: size.width, height: width))
                    for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                        let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                            hasRate: rate, skillCount: count, reservedRegions: [hinge],
                            supportsRewind: true, engineIdentifier: engine)
                        #expect(layout.canPlay, "\(size) \(vertical) \(width) \(engine)")
                        let start = rate ? 2 : 0
                        let frames = layout.interface.controlFrames
                        #expect(frames.count == start + count + 7)
                        guard frames.count == start + count + 7 else { continue }
                        let skills = Array(frames[start..<(start + count)])
                        #expect(Set(skills.map(\.minY)).count == 1, "\(size) \(vertical) \(width) \(engine)")
                        if layout.isDiorama, layout.portrait != nil {
                            #expect(skills.allSatisfy { $0.height <= 144.001 })
                        }
                        for (index, frame) in frames.enumerated() {
                            #expect(frame.width >= 44 - 0.001 && frame.height >= 44)
                            #expect(!frame.intersects(hinge.frame))
                            #expect(frames.dropFirst(index + 1).allSatisfy { !frame.intersects($0) })
                        }
                        if let deck = layout.portrait {
                            #expect(deck.skillContentWidth <= deck.skills.width + 0.001)
                        }
                    }
                }
            }
        }
    }

    @Test func scrollingMenusKeepFullWidthClearOfEachCameraCorner() {
        for size in [MobileSize(width: 495, height: 720), .init(width: 720, height: 495)] {
            let bounds = MobileRect(x: 13, y: 27, width: size.width, height: size.height)
            for leading in [false, true] {
                for top in [false, true] {
                    let camera = MobileReservedRegion(kind: .occlusion,
                        frame: .init(x: leading ? bounds.minX : bounds.maxX - 92,
                                     y: top ? bounds.minY : bounds.maxY - 80, width: 92, height: 80))
                    let viewport = MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: [camera])
                    #expect(viewport.width == bounds.width)
                    #expect(viewport.height == bounds.height - 80)
                    #expect(viewport.minY == (top ? camera.frame.maxY : bounds.minY))
                    #expect(!viewport.intersects(camera.frame))
                    for offset in [-28.0, 0, 120, 480, 900] {
                        let row = MobileRect(x: viewport.x + 16, y: viewport.y + 200 - offset,
                                             width: viewport.width - 32, height: 48)
                        let visible = MobileRect(x: row.x, y: max(row.minY, viewport.minY), width: row.width,
                            height: max(0, min(row.maxY, viewport.maxY) - max(row.minY, viewport.minY)))
                        #expect(!visible.intersects(camera.frame))
                        #expect(row.width == bounds.width - 32)
                    }
                }
            }
        }
    }

    @Test func scrollingMenusHandleBarsDivisionsAndPoseChangesWithoutRememberingOldRegions() {
        let bounds = MobileRect(x: 0, y: 0, width: 720, height: 495)
        let bar = MobileReservedRegion(kind: .occlusion, frame: .init(x: 628, y: 0, width: 92, height: 495))
        #expect(MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: [bar])
                == MobileRect(x: 0, y: 0, width: 628, height: 495))
        let book = MobileReservedRegion(kind: .division, frame: .init(x: 352, y: 0, width: 16, height: 495))
        let table = MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 240, width: 720, height: 16))
        for region in [book, table, bar, book, table] {
            let viewport = MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: [region])
            #expect(!viewport.intersects(region.frame))
            #expect(viewport.width >= 280 && viewport.height >= 88)
            #expect(MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: []) == bounds)
        }
        let nearlyFullHeight = MobileReservedRegion(kind: .occlusion,
            frame: .init(x: 628, y: 0, width: 92, height: 490))
        #expect(MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: [nearlyFullHeight]).height == 495)
    }

    @Test func fullDisplayHUDUsesBothEdgesAndAvoidsOnlyTheCamera() {
        let size = MobileSize(width: 720, height: 495)
        for leading in [false, true] {
            let camera = MobileReservedRegion(kind: .occlusion,
                frame: .init(x: leading ? 0 : 628, y: 0, width: 92, height: 80))
            let header = MobileDisplayRegions.clearHorizontalFrame(
                .init(x: 0, y: 0, width: size.width, height: 44), avoiding: [camera])
            for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(),
                    hasRate: rate, skillCount: count, reservedRegions: [camera], supportsRewind: true,
                    engineIdentifier: engine,
                    topBarInsets: .init(left: header.minX, right: size.width - header.maxX), fillsDisplayWidth: true)
                #expect(layout.interface.safeFrame.width == size.width)
                #expect(layout.interface.playfieldFrame.minX == 0 && layout.interface.playfieldFrame.maxX == size.width)
                #expect(layout.interface.controlsFrame.maxY == size.height)
                #expect(layout.interface.controlFrames.allSatisfy { !$0.intersects(camera.frame) })
                #expect(!layout.interface.statusFrame.intersects(camera.frame))
                let lower = MobileDisplayRegions.clearHorizontalFrame(
                    .init(x: 0, y: 120, width: size.width, height: 52), avoiding: [camera])
                #expect(lower.minX == 0 && lower.maxX == size.width)
            }
        }
    }

    @Test func outerDisplaySceneryFillsWidthWithoutMovingInputTargets() {
        for leading in [false, true] {
            let size = MobileSize(width: 720, height: 495)
            let insets = MobileInsets(top: 12, left: leading ? 92 : 12, bottom: 30, right: leading ? 12 : 92)
            for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                let baseline = MobileHUDLayout.make(container: size, safeArea: insets,
                    hasRate: rate, skillCount: count, engineIdentifier: engine)
                let full = MobileHUDLayout.make(container: size, safeArea: insets,
                    hasRate: rate, skillCount: count, engineIdentifier: engine, fillsDisplayWidth: true)
                #expect(full.interface.playfieldFrame.minX == 0)
                #expect(full.interface.playfieldFrame.maxX == size.width)
                #expect(full.interface.controlFrames == baseline.interface.controlFrames)
                #expect(full.interface.statusFrame == baseline.interface.statusFrame)
                #expect(full.interface.controlFrames.allSatisfy { !$0.intersects(full.interface.playfieldFrame) })
            }
        }
    }

    @Test func verticalNavigationSpaceReclaimsGameplayHeightAcrossEngines() throws {
        for leading in [false, true] {
            let size = MobileSize(width: 495, height: 720)
            let insets = MobileInsets(top: 10, left: leading ? 95 : 10, bottom: 44, right: leading ? 10 : 95)
            let rail = MobileRect(x: leading ? 4 : 404, y: 60, width: 87, height: 600)
            for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                for rewind in [false, true] {
                    let baseline = MobileHUDLayout.make(container: size, safeArea: insets,
                        hasRate: rate, skillCount: count, supportsRewind: rewind, engineIdentifier: engine)
                    let layout = MobileHUDLayout.make(container: size, safeArea: insets,
                        hasRate: rate, skillCount: count, supportsRewind: rewind, engineIdentifier: engine,
                        topBarInsets: .init(left: 12, right: 12), navigationRail: rail)
                    #expect(layout.interface.controlsPlacement == .trailingRail)
                    #expect(layout.interface.playfieldFrame.width == baseline.interface.playfieldFrame.width)
                    #expect(layout.interface.playfieldFrame.height > baseline.interface.playfieldFrame.height)
                    let deck = try #require(layout.portrait)
                    #expect(deck.skillContentWidth <= deck.skills.width + 0.001)
                    let skillStart = rate ? 2 : 0
                    let frames = layout.interface.controlFrames
                    #expect(frames.count == skillStart + count + (rewind ? 7 : 5))
                    for (index, frame) in frames.enumerated() {
                        #expect(frame.width >= 44 && frame.height >= 44)
                        #expect(!frame.intersects(layout.interface.playfieldFrame))
                        if !(skillStart..<(skillStart + count)).contains(index) {
                            #expect(frame.minX >= rail.minX && frame.maxX <= rail.maxX)
                            #expect(frame.minY >= rail.minY && frame.maxY <= rail.maxY)
                        }
                        for other in frames.dropFirst(index + 1) { #expect(!frame.intersects(other)) }
                    }
                    let pause = frames[skillStart + count]
                    let end = frames[skillStart + count + 1]
                    #expect(pause.minY == deck.skills.minY && pause.maxY == deck.skills.maxY)
                    #expect(pause.height == 80)
                    #expect(pause.maxY == min(rail.maxY, layout.interface.safeFrame.maxY))
                    #expect(end.minY == deck.minimap.minY && end.height == deck.minimap.height)
                }
            }
        }
    }

    @Test func unusableNavigationSpaceKeepsExistingLayout() {
        let size = MobileSize(width: 495, height: 720)
        let insets = MobileInsets(top: 10, left: 10, bottom: 44, right: 95)
        for rail in [MobileRect(x: 404, y: 60, width: 87, height: 200),
                     .init(x: 380, y: 60, width: 87, height: 600),
                     .init(x: 404, y: 60, width: 100, height: 600)] {
            let baseline = MobileHUDLayout.make(container: size, safeArea: insets, hasRate: true,
                skillCount: 8, supportsRewind: true)
            let layout = MobileHUDLayout.make(container: size, safeArea: insets, hasRate: true,
                skillCount: 8, supportsRewind: true, navigationRail: rail)
            #expect(layout == baseline)
        }
    }

    @Test func bookResultsKeepTheResultLeftAndAchievementsRightAcrossPoseChanges() throws {
        let safe = MobileRect(x: 0, y: 24, width: 1194, height: 786)
        let hinge = MobileReservedRegion(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))
        let camera = MobileReservedRegion(kind: .occlusion, frame: .init(x: 1138, y: 24, width: 56, height: 60))
        let panes = MobileDisplayRegions.resultPanes(in: safe, avoiding: [hinge, camera])
        #expect(panes.count == 2)
        #expect(panes[0].maxX <= hinge.frame.minX)
        #expect(panes[1].minX >= hinge.frame.maxX)
        #expect(panes.allSatisfy { !$0.intersects(hinge.frame) && !$0.intersects(camera.frame) })
        #expect(panes.allSatisfy { $0.width >= 280 && $0.height == safe.height })
        #expect(MobileDisplayRegions.resultPanes(in: safe, avoiding: []).isEmpty)
        let tableSafe = MobileRect(x: 0, y: 24, width: 834, height: 1146)
        let tableHinge = MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))
        #expect(MobileDisplayRegions.resultPanes(in: tableSafe, avoiding: [tableHinge])
            == MobileDisplayRegions.tablePanes(in: tableSafe, avoiding: [tableHinge]))
        #expect(MobileDisplayRegions.resultPanes(in: safe, avoiding: [hinge])
            == MobileDisplayRegions.bookPanes(in: safe, avoiding: [hinge]))
        #expect(MobileDisplayRegions.resultPanes(in: safe, avoiding: [hinge,
            .init(kind: .occlusion, frame: .init(x: 605, y: 0, width: 589, height: 834))]).isEmpty)
    }

    @Test func tabletopResultsRequireTwoUsableClearScreens() {
        let safe = MobileRect(x: 0, y: 24, width: 834, height: 1146)
        let division = MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))
        let cutout = MobileReservedRegion(kind: .occlusion, frame: .init(x: 0, y: 605, width: 42, height: 70))
        let panes = MobileDisplayRegions.tablePanes(in: safe, avoiding: [division, cutout])
        #expect(panes.count == 2)
        #expect(panes[0].maxY <= division.frame.minY)
        #expect(panes[1].minY >= division.frame.maxY)
        #expect(panes.allSatisfy { !$0.intersects(division.frame) && !$0.intersects(cutout.frame) })
        #expect(MobileDisplayRegions.tablePanes(in: safe, avoiding: []).isEmpty)
        #expect(MobileDisplayRegions.tablePanes(in: safe, avoiding: [
            .init(kind: .division, frame: .init(x: 405, y: 0, width: 24, height: 1194))]).isEmpty)
        #expect(MobileDisplayRegions.tablePanes(in: safe, avoiding: [division,
            .init(kind: .occlusion, frame: .init(x: 0, y: 605, width: 834, height: 565))]).isEmpty)
    }

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
                for (index, frame) in (layout.interface.controlFrames + layout.statusBanks).enumerated() {
                    let firstSkill = rate ? 2 : 0
                    if let portrait = layout.portrait, (firstSkill..<(firstSkill + skills)).contains(index) {
                        #expect(frame.minX >= portrait.skills.minX)
                        #expect(frame.maxX <= portrait.skills.minX + portrait.skillContentWidth + 0.001)
                        #expect(frame.minY >= portrait.skills.minY)
                        #expect(frame.maxY <= portrait.skills.maxY)
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
                if layout.isDiorama, regions.contains(where: { $0.kind == .division && $0.frame.width > $0.frame.height }) {
                    #expect(layout.interface.playfieldFrame.maxY <= 405)
                    #expect(layout.interface.controlsFrame.minY >= 429)
                }
            }
        }
    }

    @Test func dividedScreensKeepGameplayAcrossTheTopAndControlsFillingTheBottom() throws {
        for (size, divider) in [
            (MobileSize(width: 1194, height: 834), MobileRect(x: 589, y: 0, width: 16, height: 834)),
            (.init(width: 834, height: 1194), .init(x: 0, y: 589, width: 834, height: 16)),
            (.init(width: 650, height: 465), .init(x: 318, y: 0, width: 14, height: 465)),
            (.init(width: 465, height: 650), .init(x: 0, y: 318, width: 465, height: 14))
        ] {
            for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                    hasRate: rate, skillCount: count, reservedRegions: [.init(kind: .division, frame: divider)],
                    supportsRewind: true, hasPlayer: true, engineIdentifier: engine)
                let deck = try #require(layout.portrait)
                let field = layout.interface.playfieldFrame
                #expect(layout.canPlay)
                #expect(field.minX == layout.interface.safeFrame.minX)
                #expect(field.maxX == layout.interface.safeFrame.maxX)
                #expect(layout.interface.controlsFrame.minX == layout.interface.safeFrame.minX)
                #expect(layout.interface.controlsFrame.maxX == layout.interface.safeFrame.maxX)
                #expect(layout.interface.controlsFrame.maxY == layout.interface.safeFrame.maxY)
                if divider.height > divider.width {
                    #expect(field.intersects(divider))
                    #expect(field.maxY == layout.interface.controlsFrame.minY)
                    #expect(layout.interface.controlFrames.contains { $0.maxX <= divider.minX && $0.minY >= field.maxY })
                    #expect(layout.interface.controlFrames.contains { $0.minX >= divider.maxX && $0.minY >= field.maxY })
                } else {
                    #expect(field.maxY == divider.minY)
                    #expect(layout.interface.controlsFrame.minY == divider.maxY)
                }
                #expect(layout.interface.statusFrame.maxY == field.minY)
                #expect(deck.skillContentWidth == deck.skills.width)
                let first = rate ? 2 : 0
                let skillFrames = Array(layout.interface.controlFrames[first..<(first + count)])
                #expect(Set(skillFrames.map(\.minY)).count == 1)
                for frame in layout.interface.controlFrames[first..<(first + count)] {
                    #expect(frame.minX >= deck.skills.minX && frame.maxX <= deck.skills.maxX + 0.001)
                    #expect(frame.minY >= deck.skills.minY && frame.maxY <= deck.skills.maxY)
                }
                let bottomControls = layout.interface.controlFrames.dropLast()
                #expect(bottomControls.map(\.maxY).max() == layout.interface.safeFrame.maxY)
                #expect(min(bottomControls.map(\.minY).min()!, deck.minimap.minY) == layout.interface.controlsFrame.minY)
                #expect(bottomControls.map(\.minX).min() == layout.interface.safeFrame.minX)
                #expect(bottomControls.map(\.maxX).max() == layout.interface.safeFrame.maxX)
                let occupied = layout.interface.controlFrames + layout.statusBanks + [
                    .init(x: deck.minimap.minX, y: deck.minimap.minY, width: deck.minimap.width, height: deck.minimap.height)]
                for (index, frame) in occupied.enumerated() {
                    #expect(!frame.intersects(divider))
                    #expect(!frame.intersects(field))
                    for other in occupied.dropFirst(index + 1) {
                        #expect(!frame.intersects(other))
                    }
                }
            }
        }
    }

    @Test func compactLandscapeShowsEveryNativeSkillWithoutScrolling() throws {
        for width in [568.0, 650, 720, 834] {
            for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                let layout = MobileHUDLayout.make(container: .init(width: width, height: 465),
                    safeArea: .init(top: 20, left: 20, bottom: 20, right: 20),
                    hasRate: rate, skillCount: count, supportsRewind: true, engineIdentifier: engine)
                #expect(layout.canPlay)
                if let deck = layout.portrait {
                    #expect(deck.skillContentWidth <= deck.skills.width + 0.001)
                }
            }
        }
    }

    /// An unfolded Duo matches the iPad: the panel sits below a hinge across the screen and never spans a hinge down it.
    @Test func unfoldedDuoUsesMacPanelClearOfTheHinge() {
        let across = MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 409, width: 1194, height: 16))
        let stacked = MobileHUDLayout.make(container: .init(width: 1194, height: 834), safeArea: .init(top: 20),
                                           hasRate: true, skillCount: 8, reservedRegions: [across], supportsRewind: true)
        #expect(stacked.panel?.scale == 3)
        #expect((stacked.panel?.frame.minY ?? 0) >= 425)
        #expect(stacked.isDiorama)
        let down = MobileReservedRegion(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))
        let book = MobileHUDLayout.make(container: .init(width: 1194, height: 834), safeArea: .init(top: 20),
                                        hasRate: true, skillCount: 8, reservedRegions: [down], supportsRewind: true)
        #expect(book.panel == nil)
        #expect(book.canPlay)
    }

    @Test func wideIPadUsesMacPanelAndTinyViewsSuspend() {
        let wide = MobileHUDLayout.make(container: .init(width: 1112, height: 834),
                                        safeArea: .init(top: 20, bottom: 20), hasRate: true, skillCount: 8)
        #expect(wide.portrait == nil)
        #expect(wide.panel?.scale == 3)
        #expect(wide.interface.controlsFrame.width == 960)
        #expect(wide.interface.controlFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        // Lemmings 2 and NeoLemmix have no Classic panel artwork, so they keep the touch deck.
        let neo = MobileHUDLayout.make(container: .init(width: 1112, height: 834), safeArea: .init(top: 20, bottom: 20),
                                       hasRate: true, skillCount: 8, engineIdentifier: "neolemmix")
        #expect(neo.portrait != nil)
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

    @Test func bookHomeKeepsBothScrollingListsClearOfTheHingeAndCamera() {
        let safe = MobileRect(x: 20, y: 24, width: 1154, height: 790)
        let regions: [MobileReservedRegion] = [
            .init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
            .init(kind: .occlusion, frame: .init(x: 1120, y: 24, width: 74, height: 60))
        ]
        let panes = MobileDisplayRegions.bookPanes(in: safe, avoiding: regions)
        #expect(panes.count == 2)
        #expect(panes[0].maxX <= 589)
        #expect(panes[1].minX >= 605)
        #expect(panes.allSatisfy { $0.minY == safe.minY && $0.maxY == safe.maxY })
        #expect(panes.allSatisfy { pane in regions.allSatisfy { !pane.intersects($0.frame) } })
        #expect(MobileDisplayRegions.bookPanes(in: safe, avoiding: []).isEmpty)
        #expect(MobileDisplayRegions.bookPanes(in: safe, avoiding: [
            .init(kind: .division, frame: .init(x: 0, y: 405, width: 1194, height: 24))]).isEmpty)
    }

    @Test func roundedHeaderInsetsMoveMenuAndStatusTogetherAcrossAllEngines() throws {
        for (size, regions) in [
            (MobileSize(width: 650, height: 465), [MobileReservedRegion]()),
            (.init(width: 465, height: 650), []),
            (.init(width: 1194, height: 834), [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            (.init(width: 834, height: 1194), [.init(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))])
        ] {
            for (engine, rate, count) in [("classic", true, 8), ("lemmings2", false, 8), ("lemmings3", false, 5)] {
                for menu in [false, true] {
                    let baseline = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                        hasRate: rate, skillCount: count, reservedRegions: regions, supportsRewind: true,
                        hasPlayer: true, engineIdentifier: engine, showsMenuButton: menu)
                    let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                        hasRate: rate, skillCount: count, reservedRegions: regions, supportsRewind: true,
                        hasPlayer: true, engineIdentifier: engine, showsMenuButton: menu,
                        topBarInsets: .init(left: 60, right: 72))
                    #expect(layout.canPlay)
                    #expect(layout.interface.statusFrame.minX >= 60)
                    #expect(layout.interface.statusFrame.maxX <= size.width - 72)
                    #expect(layout.interface.playfieldFrame == baseline.interface.playfieldFrame)
                    #expect(layout.interface.controlsFrame == baseline.interface.controlsFrame)
                    #expect(layout.portrait == baseline.portrait)
                    #expect(layout.interface.statusFrame.height == 44)
                    let controls = layout.interface.controlFrames
                    if menu {
                        let headerMenu = try #require(controls.last)
                        if baseline.interface.controlFrames.last?.minY == baseline.interface.safeFrame.minY {
                            #expect(headerMenu.maxX == size.width - 72)
                            #expect(headerMenu.width == 44 && headerMenu.height == 44)
                            #expect(headerMenu.minX > layout.interface.statusFrame.maxX)
                        } else {
                            // L3's native panel keeps Menu in its lower navigation row.
                            #expect(headerMenu == baseline.interface.controlFrames.last)
                        }
                        #expect(Array(controls.dropLast()) == Array(baseline.interface.controlFrames.dropLast()))
                    } else { #expect(controls == baseline.interface.controlFrames) }
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
