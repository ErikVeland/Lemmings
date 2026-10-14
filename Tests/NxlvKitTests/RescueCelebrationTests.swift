import Testing
@testable import NxlvKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

struct RescueCelebrationTests {
    @Test func allRescuedLevelsCelebrateOnceAtTheTarget() {
        for count in [1, 10, 100] {
            var director = AdaptiveDJDirector()
            #expect(director.cue(for: .init(totalCount: count, savedCount: count - 1, requiredCount: count)) == nil)
            #expect(director.cue(for: .init(totalCount: count, savedCount: count, requiredCount: count)) == .init(reason: .won, timing: .immediate))
            #expect(director.cue(for: .init(totalCount: count, savedCount: count, requiredCount: count,
                                           didWin: true, isComplete: true)) == nil)
            #expect(director.fired == [.won])
        }
        var director = AdaptiveDJDirector()
        #expect(director.cue(for: .init(totalCount: 10, savedCount: 9, requiredCount: 9))?.reason == .won)
    }

    @Test @MainActor func briefRimExpiresWithoutRepeatingAndResetsOnRewind() {
        let glow = RescueCelebrationTransition()
        glow.set(active: true, brief: true, now: 10)
        #expect(glow.amount == 1)
        glow.advance(at: 10.175)
        #expect(glow.amount == 1)
        glow.advance(at: 11)
        #expect(glow.amount == 1)
        glow.advance(at: 12.3)
        #expect(glow.amount == 0)
        glow.set(active: true, brief: true, now: 20)
        #expect(glow.amount == 0)
        glow.set(active: false, now: 21)
        glow.set(active: true, brief: true, now: 22)
        #expect(glow.amount == 1)
        glow.advance(at: 23.5)
        #expect(glow.amount == 0)
        glow.set(active: false, now: 24)
        glow.set(active: true, now: 25)
        glow.advance(at: 27)
        #expect(glow.amount == 1)
    }
    @Test @MainActor func stableFeedbackDoesNotScheduleRepeatedRedraws() {
        let cue = RescueCelebrationTransition()
        var changes: [CGFloat] = []
        cue.onChange = { changes.append($0) }
        for frame in 0..<1_000 { cue.set(active: true, now: Double(frame) / 60) }
        #expect(changes == [1])
        cue.set(active: false, now: 20)
        #expect(changes == [1, 0])
        cue.set(active: true, brief: true, now: 21)
        for frame in 0..<1_000 { cue.advance(at: 21 + Double(frame) / 60) }
        #expect(changes == [1, 0, 1, 0])
    }
    @Test func onlySecuredTargetsAndCompletedWinsCelebrate() {
        #expect(!RescueCelebration.isSecured(saved: 0, required: 0, isComplete: false, didWin: false))
        #expect(!RescueCelebration.isSecured(saved: 4, required: 5, isComplete: false, didWin: false))
        #expect(RescueCelebration.isSecured(saved: 5, required: 5, isComplete: false, didWin: false))
        #expect(RescueCelebration.isSecured(saved: 1, required: 1, isComplete: true, didWin: true))
        #expect(!RescueCelebration.isSecured(saved: 0, required: 1, isComplete: true, didWin: false))
        #expect(!RescueCelebration.isSecured(saved: 5, required: 5, isComplete: true, didWin: false))
        #expect(RescueCelebration.isSecured(saved: 0, required: 0, isComplete: true, didWin: true))
    }

    #if canImport(CoreGraphics)
    @Test func faintRimTouchesOnlyTheSinglePixelPerimeter() throws {
        func render(_ amount: CGFloat) throws -> [UInt8] {
            let context = try #require(CGContext(data: nil, width: 120, height: 100, bitsPerComponent: 8,
                bytesPerRow: 480, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 120, height: 100))
            RescueCelebration.draw(in: CGRect(x: 10, y: 10, width: 100, height: 80), amount: amount, context: context)
            return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: 48_000))
        }
        let inactive = try render(0), earned = try render(1), half = try render(0.5)
        func rgb(_ pixels: [UInt8], _ x: Int, _ y: Int) -> [UInt8] { Array(pixels[(y * 120 + x) * 4..<(y * 120 + x) * 4 + 3]) }
        #expect(rgb(earned, 60, 50) == rgb(inactive, 60, 50))
        #expect(rgb(earned, 9, 10) == rgb(inactive, 9, 10))
        let rim = rgb(earned, 10, 50), softer = rgb(half, 10, 50)
        #expect(rim[0] > rim[1] && rim[1] > rim[2])
        #expect(rim[0] >= 24 && rim[0] <= 26)
        #expect(softer[0] > 0 && softer[0] < rim[0])
        for y in 11..<89 { for x in 11..<109 {
            #expect(rgb(earned, x, y) == rgb(inactive, x, y))
        } }
        #expect(try render(-1) == inactive)
        #expect(try render(2) == earned)
    }
    #endif
}
