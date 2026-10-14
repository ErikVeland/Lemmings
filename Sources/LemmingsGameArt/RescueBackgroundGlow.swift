#if canImport(CoreGraphics) && canImport(CoreImage)
import CoreGraphics
import NxlvKit
import CoreImage
import Foundation

/// A faint warm haze follows scenery pixels without lighting empty black space.
@MainActor public final class RescueBackgroundGlow {
    // Apple permits concurrent rendering through CIContext. Older SDKs omit its
    // Sendable annotation. Filters remain local to each rendering request.
    private struct SharedRenderer: @unchecked Sendable {
        let context = CIContext(options: [.cacheIntermediates: false])
    }
    nonisolated private static let renderer = SharedRenderer()
    private struct Key: Hashable {
        let image: ObjectIdentifier?
        let slot: String?
        let x: Int, y: Int, width: Int, height: Int, sampling: Int, radius: Int
    }
    private struct Frame {
        let source: CGImage
        let glow: CGImage
        let expansion: CGSize
        let createdAt: TimeInterval
        var bytes: Int { glow.width * glow.height * 4 }
    }
    private var cache: [Key: Frame] = [:]
    private var order: [Key] = []
    private var pending: [Key: Task<Void, Never>] = [:]
    private var cachedBytes = 0
    private let byteLimit = 16 * 1024 * 1024

    public init() {}

    public func draw(_ image: CGImage, in rect: CGRect, amount: CGFloat, context: CGContext, slot: String? = nil) {
        guard amount > 0, rect.width > 0, rect.height > 0 else { return }
        let visible = rect.intersection(context.boundingBoxOfClipPath.insetBy(dx: -18, dy: -18))
        guard !visible.isNull, !visible.isEmpty else { return }
        let crop = CGRect(x: (visible.minX - rect.minX) / rect.width * CGFloat(image.width),
            y: (visible.minY - rect.minY) / rect.height * CGFloat(image.height),
            width: visible.width / rect.width * CGFloat(image.width),
            height: visible.height / rect.height * CGFloat(image.height)).integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !crop.isEmpty else { return }
        let destination = CGRect(x: rect.minX + crop.minX / CGFloat(image.width) * rect.width,
            y: rect.minY + crop.minY / CGFloat(image.height) * rect.height,
            width: crop.width / CGFloat(image.width) * rect.width,
            height: crop.height / CGFloat(image.height) * rect.height)
        // Only the soft light may downsample. Original artwork keeps its native pixels.
        let sampling = min(1, 256 / crop.width, destination.width / crop.width, destination.height / crop.height)
        let radius = max(0.5, 6 * crop.width * sampling / destination.width)
        let key = Key(image: slot == nil ? ObjectIdentifier(image) : nil, slot: slot, x: Int(crop.minX), y: Int(crop.minY),
            width: Int(crop.width), height: Int(crop.height),
            sampling: Int((sampling * 1000).rounded()), radius: Int((radius * 1000).rounded()))
        let now = ProcessInfo.processInfo.systemUptime
        let stored = cache[key]
        // Animated Classic scenes replace their CGImage every tick. Refresh their
        // faint haze at most four times a second, independently of physics speed.
        if stored == nil || (stored?.source !== image && now - (stored?.createdAt ?? 0) >= 0.25) {
            requestFrame(image, crop: crop, sampling: sampling, radius: radius, key: key)
        }
        guard let frame = stored else { return }
        let glowRect = destination.insetBy(dx: -frame.expansion.width * destination.width,
            dy: -frame.expansion.height * destination.height)
        context.saveGState()
        defer { context.restoreGState() }
        context.setBlendMode(.screen)
        context.setAlpha(min(1, max(0, amount)) * 0.055)
        context.interpolationQuality = .low
        context.translateBy(x: glowRect.minX, y: glowRect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(frame.glow, in: CGRect(origin: .zero, size: glowRect.size))
    }

    private func requestFrame(_ image: CGImage, crop: CGRect, sampling: CGFloat, radius: CGFloat, key: Key) {
        guard pending[key] == nil, pending.count < 2 else { return }
        pending[key] = Task { [weak self] in
            let frame = await Task.detached(priority: .utility) {
                Self.makeFrame(image, crop: crop, sampling: sampling, radius: radius)
            }.value
            guard let self else { return }
            pending.removeValue(forKey: key)
            guard let frame else { return }
            if let old = cache.removeValue(forKey: key) { cachedBytes -= old.bytes; order.removeAll { $0 == key } }
            while !order.isEmpty && (order.count >= 32 || cachedBytes + frame.bytes > byteLimit) {
                if let removed = cache.removeValue(forKey: order.removeFirst()) { cachedBytes -= removed.bytes }
            }
            if frame.bytes <= byteLimit { cache[key] = frame; order.append(key); cachedBytes += frame.bytes }
        }
    }

    nonisolated private static func makeFrame(_ image: CGImage, crop: CGRect, sampling: CGFloat, radius: CGFloat) -> Frame? {
        guard let cropped = image.cropping(to: crop), let matrix = CIFilter(name: "CIColorMatrix") else { return nil }
        matrix.setValue(CIImage(cgImage: cropped).transformed(by: CGAffineTransform(scaleX: sampling, y: sampling)), forKey: kCIInputImageKey)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        for channel in ["inputRVector", "inputGVector", "inputBVector"] { matrix.setValue(zero, forKey: channel) }
        matrix.setValue(CIVector(x: 1.0 / 3, y: 1.0 / 3, z: 1.0 / 3, w: 0), forKey: "inputAVector")
        matrix.setValue(CIVector(x: 1, y: 0.76, z: 0.28, w: 0), forKey: "inputBiasVector")
        let padding = ceil(radius * 3)
        let size = CGSize(width: crop.width * sampling, height: crop.height * sampling)
        let extent = CGRect(origin: .zero, size: size).insetBy(dx: -padding, dy: -padding)
        guard let output = matrix.outputImage?.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]),
              let glow = renderer.context.createCGImage(output, from: extent, format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()) else { return nil }
        return Frame(source: image, glow: glow, expansion: CGSize(width: padding / size.width, height: padding / size.height),
            createdAt: ProcessInfo.processInfo.systemUptime)
    }
}
#endif
