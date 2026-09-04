/// One L2 airborne-motion tick, before terrain collision handling.
/// L2 uses integer velocities with countdowns, not a continuous gravity formula.
/// This implements the documented DOS routine's operation order. Full flight
/// outcomes still need collision handling and original-engine trace tests.
public struct Lemmings2AirPhysics: Equatable, Sendable {
    public private(set) var x: Int16
    public private(set) var y: Int16
    public private(set) var velocityX: Int16
    public private(set) var velocityY: Int16
    public private(set) var horizontalCountdown: Int8
    public private(set) var verticalCountdown: Int8
    public private(set) var fallDistance: Int16

    public init(x: Int16, y: Int16, velocityX: Int16, velocityY: Int16,
                horizontalCountdown: Int8, verticalCountdown: Int8,
                fallDistance: Int16 = 0) throws {
        guard (-9...8).contains(velocityY) else {
            throw SequelDataError.invalid("L2 air velocity is outside the supported acceleration table.")
        }
        self.x = x
        self.y = y
        self.velocityX = velocityX
        self.velocityY = velocityY
        self.horizontalCountdown = horizontalCountdown
        self.verticalCountdown = verticalCountdown
        self.fallDistance = fallDistance
    }

    public mutating func step() {
        // Position consumes the old velocity. Changing this order shifts arcs.
        x = x &+ velocityX
        y = y &+ velocityY
        fallDistance = velocityY < 0 ? 0 : fallDistance &+ velocityY

        // Horizontal drag stops at one pixel per tick, not zero.
        if velocityX < -1 || velocityX > 1 {
            horizontalCountdown = horizontalCountdown &- 1
            if horizontalCountdown < 0 {
                velocityX += velocityX < 0 ? 1 : -1
                horizontalCountdown = 7
            }
        }
        verticalCountdown = verticalCountdown &- 1
        if verticalCountdown < 0 {
            velocityY = min(8, velocityY + 1)
            let delays: [Int8] = [0, 0, 0, 1, 1, 2, 2, 3, 3, 8]
            verticalCountdown = delays[abs(Int(velocityY))]
        }
    }
}
