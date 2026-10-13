import AppKit
import LemmingsGameArt
import Metal

private struct FXCheckFailure: Error { let message: String }
private func fxCheck(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try value() == false { throw FXCheckFailure(message: message) }
}

func verifyAdaptiveFXPolicy() throws {
    var policy = AdaptiveFXQuality()
    for tick in 0..<120 {
        policy.observe(cpuSeconds: tick == 20 ? 0.1 : 0.003, gpuSeconds: 0.002, now: Double(tick) / 60)
    }
    try fxCheck(policy.quality == .full, "A brief spike reduced FX quality")
    for tick in 120..<480 { policy.observe(cpuSeconds: 0.02, gpuSeconds: 0.002, now: Double(tick) / 60) }
    try fxCheck(policy.quality == .minimal, "Sustained CPU load did not reduce FX quality")
    for tick in 480..<1080 { policy.observe(cpuSeconds: 0.002, gpuSeconds: 0.002, now: Double(tick) / 60) }
    try fxCheck(policy.quality == .minimal, "FX quality recovered too quickly")
    for tick in 1080..<1320 { policy.observe(cpuSeconds: 0.002, gpuSeconds: 0.002, now: Double(tick) / 60) }
    try fxCheck(policy.quality == .balanced, "FX quality did not recover one tier")
    for tick in 1320..<2100 { policy.observe(cpuSeconds: 0.002, gpuSeconds: 0.002, now: Double(tick) / 60) }
    try fxCheck(policy.quality == .full, "FX quality did not recover fully")
    policy.observe(cpuSeconds: 0.002, gpuSeconds: 0.002, now: 35, ceiling: .minimal)
    try fxCheck(policy.quality == .minimal, "Power/thermal ceiling did not apply immediately")
    for tick in 2101..<3900 { policy.observe(cpuSeconds: 0.002, gpuSeconds: 0.002, now: Double(tick) / 60, ceiling: .balanced) }
    try fxCheck(policy.quality == .balanced, "Recovery exceeded the capability ceiling")
    var gpu = AdaptiveFXQuality()
    for tick in 0..<180 { gpu.observe(cpuSeconds: 0.002, gpuSeconds: 0.02, now: Double(tick) / 60) }
    try fxCheck(gpu.quality == .balanced, "Sustained GPU load was ignored")
    var gaps = AdaptiveFXQuality()
    for tick in 0..<100 { gaps.observe(cpuSeconds: 0.02, gpuSeconds: 0, now: Double(tick) / 60) }
    gaps.observe(cpuSeconds: 0.02, gpuSeconds: 0, now: 100)
    try fxCheck(gaps.quality == .full, "Sleep counted as sustained load")
    gaps.observe(cpuSeconds: .nan, gpuSeconds: 0, now: 101)
    gaps.observe(cpuSeconds: -1, gpuSeconds: 0, now: 101)
    try fxCheck(gaps.quality == .full && gaps.smoothedCost.isFinite, "Invalid samples changed the budget")
    print("PASS adaptive FX: CPU/GPU pressure, isolated spikes, slow recovery, capability ceilings, sleep and invalid samples")
}

@MainActor func verifyMacFXRendering(root: URL) throws {
    MacFXPerformance.shared.overrideQuality = .full
    defer { MacFXPerformance.shared.overrideQuality = nil; GameCursor.gameplaySuppressed = true }
    GameCursor.gameplaySuppressed = false
    if MTLCreateSystemDefaultDevice() == nil {
        print("SKIP shipping CRT GPU checks: Metal unavailable in this process")
        return
    }
    let image = ReplayFrameCapture.image(size: CGSize(width: 64, height: 48)) {
        NSColor.black.setFill(); CGRect(x: 0, y: 0, width: 64, height: 48).fill()
        NSColor.white.setFill(); CGRect(x: 20, y: 12, width: 10, height: 18).fill()
        NSColor.green.setFill(); CGRect(x: 4, y: 38, width: 56, height: 6).fill()
    }!
    let sprite = ReplayFrameCapture.image(size: CGSize(width: 6, height: 10)) {
        NSColor.white.setFill(); CGRect(x: 1, y: 1, width: 4, height: 8).fill()
    }!
    let size = CGSize(width: 256, height: 192)
    let view = CRTView(frame: CGRect(origin: .zero, size: size))
    try fxCheck(view.isAvailable, "CRT Metal pipeline unavailable: \(view.failureReason ?? "unknown")")
    view.setSource(image, flashes: [])
    func pixels(_ texture: MTLTexture?) throws -> [UInt16] {
        guard let texture else { throw FXCheckFailure(message: "Headless CRT rendering failed") }
        var bytes = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 8,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0) }
        return bytes
    }
    let first = try pixels(view.renderForTesting(size: size))
    let uploads = view.sourceUploads, allocations = view.textureAllocations, passes = view.bloomPasses
    var effect = LemmingSelectionEffect(sprite: sprite, rect: CGRect(x: 42, y: 15, width: 6, height: 10),
                                       clipRect: CGRect(x: 0, y: 0, width: 64, height: 48))
    for opacity: CGFloat in [1, 0.6, 0.2, 0] {
        effect.opacity = opacity
        view.updateEffects(flashes: [], selection: effect)
        let actual = try pixels(view.renderForTesting(size: size))
        let fresh = CRTView(frame: view.frame)
        fresh.setSource(image, flashes: [], selection: effect)
        try fxCheck(actual == pixels(fresh.renderForTesting(size: size)), "Effect redraw retained stale pixels")
    }
    try fxCheck(view.sourceUploads == uploads && view.textureAllocations == allocations && view.bloomPasses == passes,
                "Selection fade rebuilt scene pixels, textures or bloom")
    view.settings.bloomAmount = 0
    view.updateEffects(flashes: [], selection: nil)
    let zero = try pixels(view.renderForTesting(size: size))
    try fxCheck(zero != first && view.bloomPasses == passes, "Zero bloom ran halation or retained its output")
    for quality in FXQuality.allCases {
        MacFXPerformance.shared.overrideQuality = quality
        try fxCheck(zero == pixels(view.renderForTesting(size: size)), "Adaptive FX altered the sharp base image")
        effect.opacity = 1
        view.updateEffects(flashes: [], selection: effect)
        let selected = try pixels(view.renderForTesting(size: size))
        MacFXPerformance.shared.overrideQuality = .full
        try fxCheck(selected == pixels(view.renderForTesting(size: size)), "Adaptive FX altered the selection outline")
        view.updateEffects(flashes: [], selection: nil)
    }
    MacFXPerformance.shared.overrideQuality = .full
    let flash = ExplosionFlash(rect: CGRect(x: 10, y: 10, width: 8, height: 8), strength: 1)
    let beforeFlash = view.flashUploads
    view.updateEffects(flashes: [flash], selection: nil)
    let lit = try pixels(view.renderForTesting(size: size, headroom: 8))
    try fxCheck(lit != zero && view.flashUploads == beforeFlash + 1 && view.sourceUploads == uploads,
                "Flash-only HDR redraw did not reuse the scene")
    view.updateEffects(flashes: [.init(rect: flash.rect, strength: 1, expiresAt: 0)], selection: nil)
    try fxCheck(zero == pixels(view.renderForTesting(size: size, headroom: 8)), "Expired flash retained stale light")
    let replacement = ReplayFrameCapture.image(size: CGSize(width: 64, height: 48)) {
        NSColor.blue.setFill(); CGRect(x: 0, y: 0, width: 64, height: 48).fill()
    }!
    view.setSource(replacement, flashes: [])
    try fxCheck(zero != pixels(view.renderForTesting(size: size)) && view.textureAllocations == allocations,
                "Same-size scene change reused stale pixels or allocated textures")
    let centre = CGPoint(x: 128, y: 96)
    try fxCheck(view.sourcePoint(from: centre) == CGPoint(x: 32, y: 24), "CRT input projection changed")
    print("PASS shipping CRT: unchanged-scene upload/bloom reuse, fade pixels, zero bloom, all quality tiers, flash expiry and input projection")
}

@MainActor func verifyReplayCaptureReuse() throws {
    let size = CGSize(width: 160, height: 100)
    let first = ReplayFrameCapture.image(size: size) {
        NSColor.red.setFill(); CGRect(origin: .zero, size: size).fill()
    }!
    let snapshot = first.dataProvider!.data! as Data
    let before = ReplayFrameCapture.contextAllocations
    for _ in 0..<20 {
        let next = ReplayFrameCapture.image(size: size) {
            NSColor.blue.setFill(); CGRect(x: 0, y: 0, width: 40, height: 40).fill()
        }!
        try fxCheck(first.dataProvider!.data! as Data == snapshot, "Capture changed an image retained by the encoder")
        let bytes = next.dataProvider!.data! as Data
        try fxCheck(bytes[(80 * 160 + 120) * 4 + 3] == 0, "Capture retained pixels from an earlier frame")
    }
    try fxCheck(ReplayFrameCapture.contextAllocations == before, "Capture reallocated its same-size context")
    print("PASS replay capture: retained frames stay immutable, reused surfaces clear old pixels and allocate once")
}
