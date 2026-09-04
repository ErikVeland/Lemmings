import AppKit
import Metal
import NxlvKit
import simd

// Renders the real game views offscreen to a PNG. This verifies drawing
// without needing screen-capture permission, and gives the test suite a way to
// inspect frames.

private struct ShotError: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private func render(
    directory: URL, levelIndex: Int, ticks: Int, zoom: Double, size: CGSize, output: URL,
    crtMode: String?, crtScale: Int, isNative: Bool, isLaunch: Bool
) throws {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
    let assets = try ClassicMainDATAssets.load(from: directory)
    guard levelIndex < campaign.levels.count else {
        throw ShotError(description: "level index out of range")
    }
    let entry = campaign.levels[levelIndex]
    let level = entry.level
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
    let special = level.specialStyle > 0
        ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory)
        : nil
    let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: special)

    guard let provider = CGDataProvider(data: rendered.rgba as CFData),
        let image = CGImage(
            width: rendered.width, height: rendered.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: rendered.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { throw ShotError(description: "could not build the level image") }

    var simulation = try ClassicDOSSimulation(
        level: level, renderedLevel: rendered, mainDATAssets: assets)
    for _ in 0..<ticks where !simulation.isComplete { _ = simulation.tick() }

    let panel = PanelView()
    let playfield = PlayfieldView()

    // The original screen is 320 by 200: a 320 by 160 playfield above a
    // 320 by 40 status bar. Composing at that size lets the tube stage do the
    // upscaling, which is the only way the scan line count comes out right.
    let panelHeight = isNative ? CGFloat(ClassicPanelGraphics.height) : panel.intrinsicHeight
    playfield.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height - panelHeight)
    panel.frame = CGRect(x: 0, y: 0, width: size.width, height: panelHeight)

    playfield.levelImage = image
    playfield.assets = assets
    playfield.palette = (try? ClassicLemmingPalette.inLevelVGA(
        terrainPalette: ground.terrainPalette)) ?? []
    let session = ClassicSession(
        simulation: simulation, width: rendered.width, height: rendered.height)
    playfield.session = session
    playfield.viewport.zoom = zoom
    playfield.viewport.levelSize = CGSize(width: rendered.width, height: rendered.height)
    playfield.viewport.viewSize = playfield.frame.size
    if let entrance = simulation.configuration.entrances.first {
        playfield.viewport.center(on: Double(entrance.x))
    }

    let panelPalette = ClassicLemmingPalette.panelVGA
    if let graphics = assets.panel {
        let bytes = graphics.rgba(using: panelPalette)
        if let provider = CGDataProvider(data: bytes as CFData) {
            panel.panelImage = CGImage(
                width: graphics.width, height: graphics.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: graphics.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)
        }
    }
    panel.session = session
    // Mirror the app: arm the first skill the level actually provides.
    panel.selectedSkillIndex = session.skills.firstIndex { $0.count > 0 } ?? 0
    panel.levelSize = playfield.viewport.levelSize
    panel.visibleLevelRect = playfield.viewport.visibleLevelRect
    panel.statusText = isNative
        ? ""
        : "\(entry.rank) \(entry.number) — \(level.title.trimmingCharacters(in: .whitespaces))"
        + "   Out \(simulation.releasedCount)/\(simulation.configuration.totalLemmings)"
        + "   Home \(simulation.savedCount)/\(simulation.configuration.requiredToSave)"
        + "   Rate \(simulation.releaseRate)   tick \(simulation.tickCount)"

    // Each view is rendered on its own. A windowless parent does not reliably
    // recurse into its subviews during cacheDisplay.
    func bitmap(of view: NSView) throws -> NSBitmapImageRep {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ShotError(description: "could not allocate a bitmap")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    if isLaunch {
        playfield.phase = .briefing
        playfield.overlayShowsLemmings = true
        playfield.overlayFrame = 24
        playfield.overlayTitle = "LEMMINGS"
        playfield.overlayLines = [
            "FULL QUEST  8/228",
            "LEMMINGS  8/120",
            "XMAS LEMMINGS 1991  0/4",
            "OH NO! MORE LEMMINGS  0/100",
            "XMAS LEMMINGS 1992  0/4",
        ]
        playfield.overlayHighlight = 0
        playfield.overlayFooter =
            "UP AND DOWN TO CHOOSE   \u{2022}   ENTER TO BEGIN   \u{2022}   Q TO QUIT"
        panel.statusText = ""
        panel.isMenuMode = true
    }

    let playfieldRep = try bitmap(of: playfield)
    let panelRep = try bitmap(of: panel)

    // Compose in the default bottom-left origin space. The panel sits below
    // the playfield, so it draws at y = 0.
    let composed = NSImage(size: size)
    composed.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .none
    NSColor.black.setFill()
    CGRect(origin: .zero, size: size).fill()
    panelRep.draw(in: CGRect(x: 0, y: 0, width: size.width, height: panelHeight))
    playfieldRep.draw(in: CGRect(
        x: 0, y: panelHeight, width: size.width, height: playfield.frame.height))
    composed.unlockFocus()

    guard let tiff = composed.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff)
    else { throw ShotError(description: "could not encode the frame") }

    var finalRep = rep
    if let mode = crtMode {
        guard let flat = rep.cgImage else {
            throw ShotError(description: "no frame image for the tube stage")
        }
        let settings: CRTSettings = mode == "tv" ? .television : .amiga1084
        let tube = try applyCRT(to: flat, settings: settings, scale: crtScale)
        finalRep = NSBitmapImageRep(cgImage: tube)
    }
    guard let png = finalRep.representation(using: .png, properties: [:]) else {
        throw ShotError(description: "could not encode PNG")
    }
    try png.write(to: output)

    let active = simulation.lemmings.filter(\.isActive).count
    print(
        "wrote \(output.lastPathComponent) — \(entry.rank) \(entry.number)"
            + " '\(level.title.trimmingCharacters(in: .whitespaces))'"
            + " tick \(simulation.tickCount), \(active) active, \(png.count) bytes")
}


private struct ShotCRTUniforms {
    var sourceSize: SIMD2<Float> = .zero
    var outputSize: SIMD2<Float> = .zero
    var curvature: Float = 0
    var scanlineDepth: Float = 0
    var beamWidth: Float = 0.4
    var beamBloom: Float = 0
    var maskStrength: Float = 0
    var maskType: Float = 0
    var bloomAmount: Float = 0
    var gamma: Float = 2.4
    var brightness: Float = 1
    var convergence: Float = 0
    var vignette: Float = 0
    var pixelAspect: Float = 1
    var colorLevels: Float = 0
}

/// Runs the tube shaders without a window, so the result can be inspected.
@MainActor
private func applyCRT(
    to image: CGImage, settings: CRTSettings, scale: Int
) throws -> CGImage {
    guard let device = MTLCreateSystemDefaultDevice(),
        let queue = device.makeCommandQueue()
    else { throw ShotError(description: "no Metal device") }

    let library = try device.makeLibrary(source: CRTShaders.source, options: nil)
    func pipeline(_ fragment: String, format: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "crt_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        descriptor.colorAttachments[0].pixelFormat = format
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    let width = image.width
    let height = image.height
    let outWidth = width * scale
    let outHeight = height * scale

    let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
    sourceDescriptor.usage = [.shaderRead]
    guard let source = device.makeTexture(descriptor: sourceDescriptor) else {
        throw ShotError(description: "no source texture")
    }

    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { raw in
        guard let context = CGContext(
            data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    source.replace(
        region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
        withBytes: bytes, bytesPerRow: width * 4)

    let scratchDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
    scratchDescriptor.usage = [.shaderRead, .renderTarget]
    let outDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm, width: outWidth, height: outHeight, mipmapped: false)
    outDescriptor.usage = [.shaderRead, .renderTarget]
    guard let scratchA = device.makeTexture(descriptor: scratchDescriptor),
        let scratchB = device.makeTexture(descriptor: scratchDescriptor),
        let target = device.makeTexture(descriptor: outDescriptor),
        let buffer = queue.makeCommandBuffer()
    else { throw ShotError(description: "no textures") }

    var uniforms = ShotCRTUniforms()
    uniforms.sourceSize = SIMD2(Float(width), Float(height))
    uniforms.outputSize = SIMD2(Float(outWidth), Float(outHeight))
    uniforms.curvature = settings.curvature
    uniforms.scanlineDepth = settings.scanlineDepth
    uniforms.beamWidth = settings.beamWidth
    uniforms.beamBloom = settings.beamBloom
    uniforms.maskStrength = settings.maskStrength
    uniforms.maskType = settings.maskType
    uniforms.bloomAmount = settings.bloomAmount
    uniforms.gamma = settings.gamma
    uniforms.brightness = settings.brightness
    uniforms.convergence = settings.convergence
    uniforms.vignette = settings.vignette
    uniforms.pixelAspect = settings.pixelAspect
    uniforms.colorLevels = settings.colorLevels

    func pass(
        _ state: MTLRenderPipelineState, target: MTLTexture, textures: [MTLTexture]
    ) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = target
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(state)
        for (index, texture) in textures.enumerated() {
            encoder.setFragmentTexture(texture, index: index)
        }
        encoder.setFragmentBytes(
            &uniforms, length: MemoryLayout<ShotCRTUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    pass(try pipeline("crt_bright", format: .rgba16Float), target: scratchA, textures: [source])
    pass(try pipeline("crt_blur_h", format: .rgba16Float), target: scratchB, textures: [scratchA])
    pass(try pipeline("crt_blur_v", format: .rgba16Float), target: scratchA, textures: [scratchB])
    pass(
        try pipeline("crt_composite", format: .bgra8Unorm),
        target: target, textures: [source, scratchA])

    buffer.commit()
    buffer.waitUntilCompleted()

    var output = [UInt8](repeating: 0, count: outWidth * outHeight * 4)
    target.getBytes(
        &output, bytesPerRow: outWidth * 4,
        from: MTLRegionMake2D(0, 0, outWidth, outHeight), mipmapLevel: 0)

    guard let provider = CGDataProvider(data: Data(output) as CFData),
        let result = CGImage(
            width: outWidth, height: outHeight, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: outWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { throw ShotError(description: "could not build the CRT image") }
    return result
}

// MARK: - Entry point

let arguments = CommandLine.arguments
func value(_ flag: String, _ fallback: String) -> String {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
        return fallback
    }
    return arguments[index + 1]
}

let directory = URL(fileURLWithPath: value("--data", "Content/lemming1.pc"), isDirectory: true)
let levelIndex = Int(value("--level", "1"))! - 1
let ticks = Int(value("--ticks", "150"))!
let zoom = Double(value("--zoom", "3"))!
let output = URL(fileURLWithPath: value("--out", "shot.png"))
let crtMode: String? = arguments.contains("--crt") ? value("--crt", "amiga") : nil
let crtScale = Int(value("--crt-scale", "2"))!
let isNative = arguments.contains("--native")
let isLaunch = arguments.contains("--launch")
let frameSize = isNative
    ? CGSize(width: 320, height: 200)
    : CGSize(width: 1000, height: 620)

_ = NSApplication.shared
NSApplication.shared.setActivationPolicy(.prohibited)

do {
    try MainActor.assumeIsolated {
        try render(
            directory: directory, levelIndex: levelIndex, ticks: ticks, zoom: zoom,
            size: frameSize, output: output,
            crtMode: crtMode, crtScale: crtScale, isNative: isNative,
            isLaunch: isLaunch)
    }
} catch {
    FileHandle.standardError.write(Data("Shot failed: \(error)\n".utf8))
    exit(1)
}
