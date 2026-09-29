import Testing

@testable import NxlvKit

@Suite("Double tap")
struct DoubleTapTests {
    @Test("A second press of the same key within the interval is a double tap")
    func secondPressInTime() {
        var tap = DoubleTap()
        let r1 = tap.press("+", at: 10, interval: 0.5, isRepeat: false)
        #expect(!r1)
        let r2 = tap.press("+", at: 10.3, interval: 0.5, isRepeat: false)
        #expect(r2)
        // The double tap is spent: a third press starts again.
        let r3 = tap.press("+", at: 10.5, interval: 0.5, isRepeat: false)
        #expect(!r3)
    }

    @Test("A slow second press, another key or a held repeat is not a double tap")
    func notDoubleTaps() {
        var tap = DoubleTap()
        let r4 = tap.press("+", at: 0, interval: 0.5, isRepeat: false)
        #expect(!r4)
        let r5 = tap.press("+", at: 0.8, interval: 0.5, isRepeat: false)
        #expect(!r5)
        let r6 = tap.press("-", at: 0.9, interval: 0.5, isRepeat: false)
        #expect(!r6)
        // A held key sends repeats. They never complete a double tap and they clear the first press.
        let r7 = tap.press("-", at: 1.0, interval: 0.5, isRepeat: true)
        #expect(!r7)
        let r8 = tap.press("-", at: 1.1, interval: 0.5, isRepeat: false)
        #expect(!r8)
        let r9 = tap.press("-", at: 1.2, interval: 0.5, isRepeat: false)
        #expect(r9)
    }

    @Test("Time that goes backwards cannot complete a double tap")
    func clockReset() {
        var tap = DoubleTap()
        let r10 = tap.press("+", at: 5, interval: 0.5, isRepeat: false)
        #expect(!r10)
        let r11 = tap.press("+", at: 4.9, interval: 0.5, isRepeat: false)
        #expect(!r11)
    }
}
