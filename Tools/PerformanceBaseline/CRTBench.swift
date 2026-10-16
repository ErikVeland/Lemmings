// Compile after frozen CRTView.swift and its Mac adapters in one generated file.
import AppKit
import CryptoKit
import LemmingsGameArt
import Metal
import NxlvKit

extension CRTView {
    func baselineRender(changingSource: Bool, minimal: Bool) throws -> [String: Any] {
        MacFXPerformance.shared.overrideQuality = minimal ? .minimal : .full
        defer { MacFXPerformance.shared.overrideQuality = nil }
        guard let device, let queue else { throw NSError(domain: "CRT Metal unavailable", code: 1) }
        let width = 640, height = 320
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let root = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("resources/Ports/lemmings_dos_1991-07-30")
        let level = try ClassicDataSet.detect(directory: root).campaign.levels[0].level
        let scene = try ClassicLevelRenderer.render(level, groundSet: ClassicGroundSet.load(style: level.groundStyle, from: root))
        var game = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: ClassicMainDATAssets.load(from: root))
        for _ in 0..<512 { game.tick() }
        var images: [CGImage] = []
        for _ in 0..<2 {
            let rgba = ClassicSceneFrame.rgba(scene, simulation: game)
            let provider = CGDataProvider(data: rgba as CFData)!
            let image = CGImage(width: scene.width, height: scene.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: scene.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            context.setBlendMode(.copy); context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: scene.width * 2, height: height))
            images.append(context.makeImage()!); game.tick()
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
            width: 1280, height: 640, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let target = device.makeTexture(descriptor: descriptor) else { throw NSError(domain: "CRT target unavailable", code: 2) }
        let slot = slots[0]
        var cpuSamples: [Double] = [], gpuSamples: [Double] = [], wallSamples: [Double] = []
        var referenceHash: String?
        var finalHash = ""
        for repeatIndex in 0..<8 {
            var cpu = 0.0, gpu = 0.0, wall = 0.0
            for frame in 0..<32 {
                // setSource calls render(), which prepares pixels even without
                // a window. Feed its source fields directly so prepare/upload
                // remains inside this benchmark's timed region.
                let image = images[changingSource ? frame % 2 : 0]
                if sourceImage !== image { sourceImage = image; sourceRevision &+= 1 }
                let begin = ProcessInfo.processInfo.systemUptime
                guard prepare(slot), let command = queue.makeCommandBuffer() else { throw NSError(domain: "CRT prepare failed", code: 3) }
                encode(slot, target: target, buffer: command, headroom: 1)
                command.commit()
                cpu += ProcessInfo.processInfo.systemUptime - begin
                command.waitUntilCompleted()
                wall += ProcessInfo.processInfo.systemUptime - begin
                guard command.status == .completed else { throw NSError(domain: "CRT command failed", code: 4) }
                gpu += command.gpuEndTime - command.gpuStartTime
            }
            if repeatIndex > 0 {
                cpuSamples.append(cpu * 1000 / 32)
                gpuSamples.append(gpu * 1000 / 32)
                wallSamples.append(wall * 1000 / 32)
            }
            var bytes = [UInt8](repeating: 0, count: 1280 * 640 * 8)
            target.getBytes(&bytes, bytesPerRow: 1280 * 8, from: MTLRegionMake2D(0, 0, 1280, 640), mipmapLevel: 0)
            finalHash = SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
            if let referenceHash, finalHash != referenceHash { throw NSError(domain: "CRT repeated pixels differ", code: 5) }
            referenceHash = finalHash
        }
        return ["cpuSubmitMS": cpuSamples, "gpuMS": gpuSamples, "wallMS": wallSamples,
                "rgba16SHA256": finalHash,
                "sourceUploads": sourceUploads, "bloomPasses": bloomPasses,
                "source": "640x320", "output": "1280x640"]
    }
}

@main struct CRTBaseline {
    @MainActor static func main() {
        do {
            GameCursor.gameplaySuppressed = true
            var results: [String: Any] = [:]
            for (name, changing, minimal) in [("full-static", false, false), ("full-changing", true, false), ("minimal-changing", true, true)] {
                let view = CRTView(frame: CGRect(x: 0, y: 0, width: 1280, height: 640))
                results[name] = try view.baselineRender(changingSource: changing, minimal: minimal)
            }
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
            print("PASS headless shipping CRT passes, texture readback and GPU timestamps; no window created")
        } catch { fputs("ERROR: \(error)\n", stderr); exit(1) }
    }
}
