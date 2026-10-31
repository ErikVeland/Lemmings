import Foundation
#if canImport(Darwin)
import Darwin
import os
#endif

/// Optional effects share memory with the level, decoded art and audio buffers.
public struct DeviceEffectResources: Sendable {
    public let qualityCeiling: Int
    public let enhancedEffectsAllowed: Bool
    public let maximumOverlayPixels: Int
    public let audioVoiceLimit: Int
    public let rescueVoiceLimit: Int

    public init(physicalMemory: UInt64, processorCount: Int) {
        let gib: UInt64 = 1_073_741_824
        let tier = physicalMemory <= 2 * gib ? 0 : physicalMemory <= 4 * gib ? 1 : physicalMemory <= 8 * gib ? 2 : 3
        qualityCeiling = tier == 0 ? 0 : tier == 1 ? 1 : 2
        enhancedEffectsAllowed = tier >= 2 && processorCount > 2
        // This allows for multiple buffered FP16 surfaces, masks and bloom.
        maximumOverlayPixels = [262_144, 720_000, 2_097_152, 8_388_608][tier]
        audioVoiceLimit = min(processorCount <= 2 ? 8 : 32, [8, 12, 24, 32][tier])
        rescueVoiceLimit = min(processorCount <= 2 ? 4 : 64, [4, 8, 24, 64][tier])
    }

    private init(qualityCeiling: Int, enhancedEffectsAllowed: Bool, maximumOverlayPixels: Int,
                 audioVoiceLimit: Int, rescueVoiceLimit: Int) {
        self.qualityCeiling = qualityCeiling; self.enhancedEffectsAllowed = enhancedEffectsAllowed
        self.maximumOverlayPixels = maximumOverlayPixels
        self.audioVoiceLimit = audioVoiceLimit; self.rescueVoiceLimit = rescueVoiceLimit
    }

    public func underPressure(thermalLevel: Int, lowPower: Bool, memoryPressure: Bool) -> Self {
        let thermal = max(0, min(3, thermalLevel))
        let ceiling = memoryPressure || thermal >= 2 ? 0 : lowPower || thermal == 1 ? 1 : 2
        return Self(qualityCeiling: min(qualityCeiling, ceiling),
                    enhancedEffectsAllowed: enhancedEffectsAllowed && !lowPower && !memoryPressure && thermal < 2,
                    maximumOverlayPixels: memoryPressure ? min(maximumOverlayPixels, 262_144) : maximumOverlayPixels,
                    audioVoiceLimit: min(audioVoiceLimit, memoryPressure ? 6 : 32, lowPower ? 12 : 32, [32, 16, 10, 6][thermal]),
                    rescueVoiceLimit: min(rescueVoiceLimit, memoryPressure ? 2 : 64, lowPower ? 4 : 64, [64, 8, 4, 2][thermal]))
    }

    public func limitingAudio(toQuality quality: Int) -> Self {
        let quality = max(0, min(2, quality))
        return Self(qualityCeiling: qualityCeiling, enhancedEffectsAllowed: enhancedEffectsAllowed,
                    maximumOverlayPixels: maximumOverlayPixels,
                    audioVoiceLimit: min(audioVoiceLimit, [6, 12, 32][quality]),
                    rescueVoiceLimit: min(rescueVoiceLimit, [2, 8, 64][quality]))
    }
}

/// One process-wide pressure monitor. Audio callbacks never poll system state.
public final class DeviceEffectPressure: @unchecked Sendable {
    public static let shared = DeviceEffectPressure()
    private let lock = NSLock()
    private let source: DispatchSourceMemoryPressure
    private let base: DeviceEffectResources
    private var cached: DeviceEffectResources
    private var lastPoll = -Double.infinity
    private var memoryPressureUntil = -Double.infinity
    private var audioQuality = 2

    private init() {
        let process = ProcessInfo.processInfo
        base = DeviceEffectResources(physicalMemory: process.physicalMemory, processorCount: process.processorCount)
        cached = base
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in self?.noteMemoryPressure() }
        source.resume()
    }

    deinit { source.cancel() }

    /// Hold the smaller budget for a minute to avoid repeated allocation cycles.
    public func noteMemoryPressure() {
        RuntimeMemoryBudget.shared.noteMemoryPressure()
        lock.lock(); defer { lock.unlock() }
        memoryPressureUntil = ProcessInfo.processInfo.systemUptime + 60
        lastPoll = -.infinity
    }

    /// Sustained frame cost also limits the audio work admitted by every engine.
    public func setAudioQuality(_ quality: Int) {
        lock.lock(); defer { lock.unlock() }
        let quality = max(0, min(2, quality))
        guard quality != audioQuality else { return }
        audioQuality = quality; lastPoll = -.infinity
    }

    public func snapshot() -> DeviceEffectResources {
        lock.lock(); defer { lock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPoll >= 1 else { return cached }
        lastPoll = now
        let process = ProcessInfo.processInfo
        let thermal: Int
        switch process.thermalState {
        case .nominal: thermal = 0
        case .fair: thermal = 1
        case .serious: thermal = 2
        case .critical: thermal = 3
        @unknown default: thermal = 3
        }
        cached = base.underPressure(thermalLevel: thermal, lowPower: process.isLowPowerModeEnabled,
                                  memoryPressure: now < memoryPressureUntil).limitingAudio(toQuality: audioQuality)
        return cached
    }
}

/// One process budget for retained scene caches and rewind acceleration.
/// Footprint is measured; retained collection sizes remain conservative estimates.
public final class RuntimeMemoryBudget: @unchecked Sendable {
    public static let shared = RuntimeMemoryBudget()
    public struct Snapshot: Sendable {
        public let historyBytes: Int
        public let cacheBytes: Int
        public let footprintBytes: UInt64
        public let peakFootprintBytes: UInt64
        public let availableBytes: UInt64?
    }
    private let lock = NSLock()
    private var lastSample = -Double.infinity
    private var pressureUntil = -Double.infinity
    private var peak: UInt64 = 0
    private var cacheLeases: [UUID: Int] = [:]
    private var leasedBytes = 0
    private var cached = Snapshot(historyBytes: 16 * 1_048_576, cacheBytes: 4 * 1_048_576,
                                  footprintBytes: 0, peakFootprintBytes: 0, availableBytes: nil)
    public init() {}
    public var retainedCacheBytes: Int { lock.lock(); defer { lock.unlock() }; return leasedBytes }
    fileprivate func reserveCache(_ id: UUID, bytes: Int) -> Bool {
        let limit = snapshot().cacheBytes
        lock.lock(); defer { lock.unlock() }
        let previous = cacheLeases[id] ?? 0
        let requested = max(0, bytes)
        guard requested == 0 || requested <= limit && leasedBytes - previous <= limit - requested else {
            leasedBytes -= previous; cacheLeases.removeValue(forKey: id)
            return false
        }
        leasedBytes += requested - previous
        if requested == 0 { cacheLeases.removeValue(forKey: id) } else { cacheLeases[id] = requested }
        return true
    }
    public func noteMemoryPressure() {
        lock.lock(); defer { lock.unlock() }
        pressureUntil = ProcessInfo.processInfo.systemUptime + 60
        lastSample = -.infinity
    }
    public func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSample >= 1 else { return cached }
        lastSample = now
        let process = ProcessInfo.processInfo
        var footprint: UInt64 = 0
        var available: UInt64?
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS { footprint = info.phys_footprint }
        #if os(iOS) || os(tvOS)
        let reportedAvailable = UInt64(os_proc_available_memory())
        #if targetEnvironment(simulator)
        // The hostless simulator test runner is not an app and has no app allowance.
        if reportedAvailable != 0 || process.processName != "xctest" { available = reportedAvailable }
        #else
        available = reportedAvailable
        #endif
        #endif
        #endif
        peak = max(peak, footprint)
        let tier = process.physicalMemory <= 2 * 1_073_741_824 ? 0 : process.physicalMemory <= 4 * 1_073_741_824 ? 1 : 2
        var history = [16, 32, 64][tier] * 1_048_576
        var cache = [4, 8, 16][tier] * 1_048_576
        if let available {
            history = min(history, Int(min(UInt64(Int.max), available / 8)))
            cache = min(cache, Int(min(UInt64(Int.max), available / 16)))
        }
        if now < pressureUntil || process.thermalState == .critical {
            history = min(history, 4 * 1_048_576)
            cache = 0
        }
        cached = .init(historyBytes: max(1, history), cacheBytes: cache,
                       footprintBytes: footprint, peakFootprintBytes: peak, availableBytes: available)
        return cached
    }
}

/// Heavy optional pixel caches share a single admission ceiling across engines.
public final class RuntimePixelCacheLease: @unchecked Sendable {
    private let id = UUID()
    public init() {}
    public func reserve(bytes: Int) -> Bool { RuntimeMemoryBudget.shared.reserveCache(id, bytes: bytes) }
    public func release() { _ = reserve(bytes: 0) }
    deinit { release() }
}
