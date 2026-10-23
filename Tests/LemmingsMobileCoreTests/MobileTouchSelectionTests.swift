import Testing
@testable import LemmingsMobileCore

struct MobileTouchSelectionTests {
    private let point = MobilePoint(x: 80, y: 60)
    private var viewport: MobileViewport {
        .init(levelSize: .init(width: 640, height: 160), viewSize: .init(width: 320, height: 160), zoom: 1)
    }
    private func actor(_ id: Int, x: Double = 80, state: MobileAssignmentState = .eligible) -> MobileTargetCandidate {
        .init(id: id, point: .init(x: x, y: 60), direction: 1, assignment: state)
    }

    @Test func holdStartsOnceAndHorizontalScrubbingHasADeadZone() {
        var router = MobileTouchRouter()
        #expect(router.began(id: 1, at: point, time: 1, allowsHolding: true) == [.preview(point)])
        #expect(router.advance(at: 1.3).isEmpty)
        #expect(router.advance(at: 1.4) == [.holdSelection(point)])
        #expect(router.advance(at: 2).isEmpty)
        #expect(router.moved(id: 1, to: .init(x: 100, y: 100)) == [.movePreview(.init(x: 100, y: 100))])
        #expect(router.moved(id: 1, to: .init(x: 104, y: 100)).last == .browseSelection(1))
        #expect(router.moved(id: 1, to: point).last == .browseSelection(-1))
        #expect(router.ended(id: 1, at: point, time: 3) == [.commitSelection])
        #expect(!router.isHoldingSelection)
    }

    @Test func fastDragStillPansAndEmptySpaceCannotBecomeAHeldSelection() {
        var router = MobileTouchRouter()
        _ = router.began(id: 1, at: point, time: 1, allowsHolding: true)
        #expect(router.moved(id: 1, to: .init(x: 100, y: 60), time: 1.1).contains(.cancelPreview))
        #expect(router.advance(at: 2).isEmpty)
        #expect(router.ended(id: 1, at: .init(x: 100, y: 60), time: 2) == [.cancelPreview])
        _ = router.began(id: 2, at: point, time: 3)
        #expect(router.advance(at: 4).isEmpty)
        #expect(router.moved(id: 2, to: .init(x: 100, y: 60)).last == .pan(.init(x: 20, y: 0)))
    }

    @Test func holdCanStartOnTheFirstMovementAfterTheDelay() {
        var router = MobileTouchRouter()
        _ = router.began(id: 1, at: point, time: 1, allowsHolding: true)
        let effects = router.moved(id: 1, to: .init(x: 104, y: 60), time: 1.4)
        #expect(effects == [.holdSelection(point), .movePreview(.init(x: 104, y: 60)), .browseSelection(1)])
    }

    @Test func restingAtAnEdgeKeepsBrowsingDenseCrowdsWithoutLifting() {
        var router = MobileTouchRouter()
        let edge = MobilePoint(x: 310, y: 60)
        _ = router.began(id: 1, at: edge, time: 1, allowsHolding: true)
        _ = router.advance(at: 1.4, horizontalRange: 0...320)
        #expect(router.advance(at: 1.5, horizontalRange: 0...320).isEmpty)
        #expect(router.advance(at: 1.7, horizontalRange: 0...320).isEmpty)
        #expect(router.advance(at: 1.9, horizontalRange: 0...320) == [.browseSelection(1)])
        #expect(router.advance(at: 2.0, horizontalRange: 0...320).isEmpty)
        #expect(router.advance(at: 2.1, horizontalRange: 0...320) == [.browseSelection(1)])
        _ = router.moved(id: 1, to: .init(x: 160, y: 60))
        #expect(router.advance(at: 2.5, horizontalRange: 0...320).isEmpty)
        _ = router.moved(id: 1, to: .init(x: 10, y: 60))
        #expect(router.advance(at: 3.0, horizontalRange: 0...320).isEmpty)
        #expect(router.advance(at: 3.4, horizontalRange: 0...320) == [.browseSelection(-1)])
        #expect(router.cancel() == [.cancelPreview])
        #expect(router.advance(at: 4, horizontalRange: 0...320).isEmpty)
    }

    @Test(arguments: [false, true]) func secondFingerPansAndOnlyTheSelectionFingerCommits(cameraLiftsFirst: Bool) {
        var router = MobileTouchRouter()
        _ = router.began(id: 1, at: point, time: 1, allowsHolding: true)
        _ = router.advance(at: 1.4)
        #expect(router.began(id: 2, at: .init(x: 200, y: 60), time: 1.5).isEmpty)
        #expect(router.moved(id: 2, to: .init(x: 180, y: 70)) == [.panHoldingSelection(.init(x: -20, y: 10))])
        #expect(router.isHoldingSelection)
        if cameraLiftsFirst { #expect(router.ended(id: 2, at: point, time: 2).isEmpty) }
        #expect(router.ended(id: 1, at: point, time: 2.1) == [.commitSelection])
        if !cameraLiftsFirst {
            #expect(router.moved(id: 2, to: point).isEmpty)
            #expect(router.ended(id: 2, at: point, time: 2.2).isEmpty)
            #expect(router.began(id: 3, at: point, time: 2.3).isEmpty)
        }
        router.resetAfterAllTouchesEnded()
        #expect(router.began(id: 4, at: point, time: 3) == [.preview(point)])
    }

    @Test func extraContactsAndCancellationNeverAssign() {
        var router = MobileTouchRouter()
        _ = router.began(id: 1, at: point, time: 1, allowsHolding: true)
        _ = router.advance(at: 1.4)
        _ = router.began(id: 2, at: point, time: 1.5)
        #expect(router.began(id: 3, at: point, time: 1.6) == [.cancelPreview])
        #expect(router.ended(id: 1, at: point, time: 2).isEmpty)
        #expect(router.moved(id: 2, to: point).isEmpty)
        router.resetAfterAllTouchesEnded()
        _ = router.began(id: 4, at: point, time: 3, allowsHolding: true)
        _ = router.advance(at: 3.4)
        #expect(router.cancel() == [.cancelPreview])
        #expect(router.ended(id: 4, at: point, time: 4).isEmpty)
    }

    @Test func browseOrderStaysFixedAndEndsDoNotWrap() throws {
        let crowd = [actor(3), actor(1), actor(2), actor(4, x: 111)]
        var selection = try #require(MobileTouchSelection(candidates: crowd, touch: point, viewport: viewport, selectedID: 1))
        #expect(selection.ids == [1, 2, 3])
        selection.browse(by: 1, candidates: Array(crowd.reversed()))
        #expect(selection.selection(in: crowd)?.id == 2)
        selection.browse(by: 100, candidates: crowd)
        #expect(selection.selection(in: crowd)?.id == 3)
        selection.browse(by: -100, candidates: crowd)
        #expect(selection.selection(in: crowd)?.id == 1)
    }

    @Test func chosenActorFollowsMovementAndEligibilityWithoutReplacement() throws {
        var selection = try #require(MobileTouchSelection(candidates: [actor(1), actor(2)],
            touch: point, viewport: viewport, selectedID: 1))
        let moved = [actor(1, x: 400, state: .unavailable), actor(2), actor(3)]
        #expect(selection.selection(in: moved)?.id == 1)
        #expect(selection.selection(in: moved)?.point.x == 400)
        #expect(selection.selection(in: moved)?.state == .unavailable)
        #expect(selection.selection(in: [actor(2)]) == nil)
        selection.browse(by: 1, candidates: [actor(2), actor(3)])
        #expect(selection.selection(in: moved)?.id == 2)
        selection.browse(by: 1, candidates: moved)
        #expect(selection.selection(in: moved)?.id == 2)
    }

    @Test func browsingSkipsLostActorsAndRetainsIneligibleActors() throws {
        var selection = try #require(MobileTouchSelection(candidates: [actor(1), actor(2), actor(3)],
            touch: point, viewport: viewport, selectedID: 1))
        let survivors = [actor(1), actor(3, state: .alreadyAssigned)]
        selection.browse(by: 1, candidates: survivors)
        #expect(selection.selection(in: survivors)?.id == 3)
        #expect(selection.selection(in: survivors)?.state == .alreadyAssigned)
        selection.browse(by: -1, candidates: survivors)
        #expect(selection.selection(in: survivors)?.id == 1)
    }

    @Test(arguments: [1.0, 2.0, 4.0]) func crowdRadiusUsesScreenPointsAcrossZoom(zoom: Double) throws {
        let camera = MobileViewport(levelSize: .init(width: 640, height: 160),
            viewSize: .init(width: 320, height: 160),
            origin: .init(x: 80 - 160 / (zoom * 1.2), y: 60 - 80 / zoom), zoom: zoom, pixelAspect: 1.2)
        let centre = camera.viewPoint(fromLevel: point)
        let crowd = [actor(1), actor(2, x: 80 + 29 / (zoom * 1.2)), actor(3, x: 80 + 31 / (zoom * 1.2))]
        let selection = try #require(MobileTouchSelection(candidates: crowd, touch: centre, viewport: camera, selectedID: 1))
        #expect(selection.ids == [1, 2])
    }
}
