#if os(iOS)
import Foundation
import Metal

/// Older GPUs and two-core iPads reserve more time for simulation and audio.
enum MobileDevicePerformance {
    static let constrained: Bool = {
        guard ProcessInfo.processInfo.processorCount > 2,
              let device = MTLCreateSystemDefaultDevice() else { return true }
        return !device.supportsFamily(.apple4)
    }()
}
#endif
