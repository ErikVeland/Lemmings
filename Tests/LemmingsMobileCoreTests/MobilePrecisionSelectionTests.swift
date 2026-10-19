import Testing
@testable import LemmingsMobileCore

struct MobilePrecisionSelectionTests {
    private let candidates = [
        MobileTargetCandidate(id: 1, point: .init(x: 80, y: 60), direction: 1, assignment: .eligible),
        MobileTargetCandidate(id: 2, point: .init(x: 100, y: 60), direction: 1, assignment: .eligible),
    ]

    @Test func stationaryPointerChangesTargetWhenPausedCameraPans() {
        var state = MobilePlayState()
        state.resume(isForeground: true, isInterrupted: false)
        state.pauseForPlanning()
        var viewport = MobileViewport(levelSize: .init(width: 640, height: 160),
                                      viewSize: .init(width: 320, height: 160), zoom: 1)
        let pointer = MobilePoint(x: 80, y: 60)
        #expect(pick(pointer, viewport: viewport)?.id == 1)
        viewport.pan(viewDelta: .init(x: -20, y: 0))
        #expect(pick(pointer, viewport: viewport)?.id == 2)
        viewport.pan(viewDelta: .init(x: -20, y: 0))
        #expect(pick(pointer, viewport: viewport) == nil)
        #expect(state.isPaused && state.canEdit)
    }

    @Test(arguments: [0.75, 1.0, 2.0, 4.0, 12.0])
    func precisionBoundsFollowZoomAndPixelAspect(zoom: Double) {
        let viewport = MobileViewport(levelSize: .init(width: 640, height: 160),
                                      viewSize: .init(width: 320, height: 320),
                                      origin: .init(x: 80 - 320 / (zoom * 1.2) / 2, y: 60 - 320 / zoom / 2),
                                      zoom: zoom, pixelAspect: 1.2)
        // Test one candidate to keep skill eligibility from choosing a neighbour.
        func selection(x: Double, y: Double) -> MobileTargetSelection? {
            MobileTargetSelector.select(candidates: [candidates[0]],
                touch: viewport.viewPoint(fromLevel: .init(x: x, y: y)), viewport: viewport,
                favourApproaching: false, input: .precision)
        }
        #expect(selection(x: 80, y: 60)?.id == 1)
        #expect(selection(x: 85.99, y: 60)?.id == 1)
        #expect(selection(x: 86.01, y: 60) == nil)
        #expect(selection(x: 80, y: 51.01)?.id == 1)
        #expect(selection(x: 80, y: 50.99) == nil)
        #expect(selection(x: 80, y: 69.99)?.id == 1)
        #expect(selection(x: 80, y: 70.01) == nil)
    }

    @Test func precisionDoesNotUseTheFingerAllowanceAcrossACrowd() {
        let viewport = MobileViewport(levelSize: .init(width: 640, height: 160),
                                      viewSize: .init(width: 320, height: 160), zoom: 1)
        let gap = MobilePoint(x: 90, y: 60)
        #expect(MobileTargetSelector.select(candidates: candidates, touch: gap,
            viewport: viewport, favourApproaching: false, input: .touch) != nil)
        #expect(pick(gap, viewport: viewport) == nil)
    }

    @Test func pointerBoundsKeepSequelSpriteGeometryAndSkillEligibility() {
        let viewport = MobileViewport(levelSize: .init(width: 640, height: 160),
                                      viewSize: .init(width: 320, height: 160), zoom: 1)
        let sequel = MobileTargetCandidate(id: 3, point: .init(x: 80, y: 60), direction: 1,
            assignment: .unavailable, pointerBounds: .init(x: -9, y: -12, width: 18, height: 24))
        let edge = MobilePoint(x: 88.9, y: 71.9)
        #expect(MobileTargetSelector.select(candidates: [sequel], touch: edge, viewport: viewport,
            input: .precision)?.state == .unavailable)
        #expect(MobileTargetSelector.select(candidates: [sequel], touch: .init(x: 89.1, y: 60),
            viewport: viewport, input: .precision) == nil)
    }

    @Test func precisionRejectsTheLetterboxAndOutsideThePlayfield() {
        let viewport = MobileViewport(levelSize: .init(width: 160, height: 80),
                                      viewSize: .init(width: 320, height: 160), zoom: 1)
        let edge = MobileTargetCandidate(id: 1, point: .init(x: 1, y: 1), direction: 1, assignment: .eligible)
        #expect(MobileTargetSelector.select(candidates: [edge], touch: .init(x: 79, y: 41),
            viewport: viewport, input: .precision) == nil)
        #expect(pick(.init(x: -1, y: 60), viewport: viewport) == nil)
    }

    @Test func pencilCanAdjustAimBeforeCommittingWithoutPanning() {
        var router = MobileTouchRouter()
        let start = MobilePoint(x: 20, y: 20), end = MobilePoint(x: 100, y: 60)
        #expect(router.began(id: 1, at: start, time: 1, allowsPanning: false) == [.preview(start)])
        #expect(router.moved(id: 1, to: end) == [.movePreview(end)])
        #expect(router.ended(id: 1, at: end, time: 2) == [.commit(end)])
        _ = router.began(id: 2, at: start, time: 3, allowsPanning: false)
        #expect(router.cancel() == [.cancelPreview])
        #expect(router.ended(id: 2, at: end, time: 4).isEmpty)
        _ = router.began(id: 3, at: start, time: 5)
        #expect(router.moved(id: 3, to: end).contains(.pan(.init(x: 80, y: 40))))
        #expect(router.ended(id: 3, at: end, time: 6) == [.cancelPreview])
    }

    @Test(arguments: [-1, 1])
    func wallFacingActorReplacesARetainedActorThatHasTurnedAway(side: Int) {
        let viewport = MobileViewport(levelSize: .init(width: 160, height: 80),
                                      viewSize: .init(width: 160, height: 80), zoom: 1)
        // Aim just behind the crowd. The wall must override the pointer's side.
        let point = MobilePoint(x: 40 - Double(side) * 2, y: 40)
        let actors = [
            MobileTargetCandidate(id: 1, point: .init(x: 40, y: 40), direction: -side, assignment: .eligible),
            MobileTargetCandidate(id: 2, point: .init(x: 40 + Double(side), y: 40), direction: side, assignment: .eligible),
        ]
        let chosen = MobileTargetSelector.select(candidates: actors, touch: point, viewport: viewport,
            input: .precision, retaining: 1, wallDirectionForTarget: { _ in side })
        #expect(chosen?.id == 2 && chosen?.state == .eligible)
        #expect(MobileTargetSelector.select(candidates: actors, touch: point, viewport: viewport,
            favourApproaching: false, input: .precision, retaining: 1,
            wallDirectionForTarget: { _ in side })?.id == 1)
    }

    @Test func ordinaryCrowdRetentionDoesNotSwitchWithEachCrossing() {
        let viewport = MobileViewport(levelSize: .init(width: 160, height: 80),
                                      viewSize: .init(width: 160, height: 80), zoom: 1)
        let point = MobilePoint(x: 40, y: 40)
        for x in [39.0, 40, 41] {
            let actors = [
                MobileTargetCandidate(id: 1, point: .init(x: x, y: 40), direction: 1, assignment: .eligible),
                MobileTargetCandidate(id: 2, point: point, direction: -1, assignment: .eligible),
            ]
            #expect(MobileTargetSelector.select(candidates: actors, touch: point, viewport: viewport,
                input: .precision, retaining: 1)?.id == 1)
        }
    }

    @Test func wallPreferenceKeepsEligibilityToolsAndPickBounds() {
        let viewport = MobileViewport(levelSize: .init(width: 160, height: 80),
                                      viewSize: .init(width: 160, height: 80), zoom: 1)
        let point = MobilePoint(x: 40, y: 40)
        let carrier = MobileTargetCandidate(id: 1, point: point, direction: 1, assignment: .eligible, hasTool: true)
        let unavailable = MobileTargetCandidate(id: 2, point: point, direction: -1, assignment: .unavailable)
        let outside = MobileTargetCandidate(id: 3, point: .init(x: 60, y: 40), direction: -1, assignment: .eligible)
        let emptyHanded = MobileTargetCandidate(id: 4, point: point, direction: -1, assignment: .eligible)
        #expect(MobileTargetSelector.select(candidates: [carrier, unavailable, outside], touch: point,
            viewport: viewport, input: .precision, retaining: 1, wallDirectionForTarget: { _ in -1 })?.id == 1)
        #expect(MobileTargetSelector.select(candidates: [carrier, emptyHanded], touch: point,
            viewport: viewport, preference: .toolHolder, input: .precision, retaining: 1,
            wallDirectionForTarget: { _ in -1 })?.id == 1)
    }

    @Test func exactAimDoesNotInventAnApproachDirection() {
        let viewport = MobileViewport(levelSize: .init(width: 160, height: 80),
                                      viewSize: .init(width: 160, height: 80), zoom: 1)
        let actors = [
            MobileTargetCandidate(id: 1, point: .init(x: 41, y: 40), direction: 1, assignment: .eligible),
            MobileTargetCandidate(id: 2, point: .init(x: 40, y: 40), direction: -1, assignment: .eligible),
        ]
        for actor in actors {
            #expect(MobileTargetSelector.select(candidates: actors, touch: actor.point,
                viewport: viewport, input: .precision)?.id == actor.id)
        }
    }

    private func pick(_ point: MobilePoint, viewport: MobileViewport) -> MobileTargetSelection? {
        MobileTargetSelector.select(candidates: candidates, touch: point, viewport: viewport,
                                    favourApproaching: false, input: .precision)
    }
}
