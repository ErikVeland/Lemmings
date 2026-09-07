import Foundation

/// Fixed-point fan motion from PROCESS a441, including the original lookup rounding.
public enum Lemmings2FanPhysics {
    public enum Mode: Sendable { case parachute, balloon, icarus, hangGlider, jetPack, twister, magicCarpet, surfer }
    public struct Motion: Equatable, Sendable {
        public let velocityX: Int
        public let velocityY: Int
        public let deltaX: Int
        public let deltaY: Int
    }
    public static func power(heldTicks: Int) -> Int {
        let index = min(37, max(0, heldTicks) / 2)
        let tier = index < 16 ? index / 4 : index < 24 ? 4 : index < 29 ? 5
            : index < 33 ? 6 : index < 36 ? 7 : 8
        return [0,12800,25600,38400,51200,76800,128000,204800,307200][tier]
    }
    public static func step(x: Int, y: Int, velocityX: Int, velocityY: Int,
                            fanX: Int, fanY: Int, power: Int, mode: Mode = .parachute, lift: Int = 0) -> Motion {
        let anchor: Int
        switch mode {
        case .balloon: anchor = 20
        case .icarus: anchor = 6
        case .hangGlider, .magicCarpet: anchor = 2
        case .jetPack, .twister: anchor = 5
        case .surfer: anchor = 8
        case .parachute: anchor = 16
        }
        let roundsBeforeDrag = mode == .jetPack || mode == .magicCarpet
        let dx = x - fanX, dy = y - anchor - fanY
        if mode != .parachute && mode != .jetPack && mode != .magicCarpet && (abs(dx) > 127 || abs(dy) >= 127 || ((mode == .icarus || mode == .twister || mode == .surfer) && power == 0)) {
            return Motion(velocityX:velocityX,velocityY:velocityY,deltaX:0,deltaY:mode == .balloon ? -1 : 0)
        }
        var forceX = 0, forceY = 0
        if abs(dx) <= 127 && abs(dy) < 127 {
            let square = dx * dx + dy * dy
            let distance = Int(Double(square).squareRoot()) + 1
            let ratio = min(255, abs(dy) * 256 / distance)
            let angle = Int((asin(Double(ratio) / 256) * 180 / .pi).rounded())
            var sine = Int((sin(Double(angle) * .pi / 180) * 256).rounded())
            var cosine = Int((cos(Double(angle) * .pi / 180) * 256).rounded())
            // Seven entries in the original tables differ from rounded trig values.
            if angle == 82 { sine = 253 }
            if let value = [37:205,54:151,57:140,80:45,87:14,89:5][angle] { cosine = value }
            let boundedPower = max(0, min(0xffff_ffff, power))
            let magnitude = square + 1 > boundedPower >> 16 ? boundedPower / (square + 1) : 0
            let shift = mode == .twister ? 10 : mode == .surfer ? 9 : mode == .balloon ? 6 : mode == .hangGlider ? 9 : mode == .jetPack ? 8 : 7
            forceX = (((cosine * magnitude) >> shift) & 1023) * (dx < 0 ? -1 : 1)
            forceY = (((sine * magnitude) >> shift) & 1023) * (dy < 0 ? -1 : 1)
        }
        var rawX = Int(Int16(truncatingIfNeeded: velocityX + forceX))
        var rawY = Int(Int16(truncatingIfNeeded: velocityY + forceY - (roundsBeforeDrag ? lift : 0)))
        if roundsBeforeDrag {
            if rawX < 0 { rawX += 128 }
            if rawY < 0 { rawY += 128 }
        }
        let vx = Int(Int16(truncatingIfNeeded: rawX - (rawX >> 2)))
        let vy = Int(Int16(truncatingIfNeeded: rawY - (rawY >> 2)))
        return Motion(velocityX: vx, velocityY: vy,
            deltaX: (vx + (vx < 0 && !roundsBeforeDrag ? 128 : 0)) >> 8,
            deltaY: ((vy + (vy < 0 && !roundsBeforeDrag ? 128 : 0)) >> 8) - (mode == .balloon ? 1 : 0))
    }
}
