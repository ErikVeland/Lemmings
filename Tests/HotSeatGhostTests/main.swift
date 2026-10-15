import AppKit
import LemmingsAppCore
import NxlvKit
import QuartzCore

@MainActor func runGhostChecks() throws {
    let appStorage = try AppStorage.temporary(named: "hot-seat-ghosts")
    defer { appStorage.removeTemporaryFiles() }
    ArcadeStore.shared = ArcadeStore(storage: appStorage, bundledProofs: nil)
    let directory = URL(fileURLWithPath: "Sources/Ports/lemmings_dos_1991-07-30")
    let level = try ClassicDataSet.detect(directory: directory).campaign.levels[0].level
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
    let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
    let assets = try ClassicMainDATAssets.load(from: directory)
    let classic = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: assets)
    let l2 = try Lemmings2PlayWindow(root: URL(fileURLWithPath: "Sources/Ports/Lemm2"), recordsCampaignProgress: false)
    let l3 = try Lemmings3PlayWindow(root: URL(fileURLWithPath: "Sources/Ports/LEM3CD"), recordsCampaignProgress: false)
    defer { l2.stop(); l3.stop(); l2.window?.orderOut(nil); l3.window?.orderOut(nil) }
    let c2 = l2.hotSeatGhostTestContext()!, c3 = l3.leaderboardReplayContext()
    let field = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 1120, height: 640))
    field.classicScene = scene; field.assets = assets; field.palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
    field.levelImage = fieldImage(scene, terrain: classic.terrain); field.imageScale = 1
    let contexts: [(ActionReplayState, NSView, (ActionReplayState) -> Void)] = [
        (.classic(classic), field, { state in
            guard case .classic(let game) = state else { return }
            field.session = ClassicSession(simulation: game, width: scene.width, height: scene.height)
            field.viewport.levelSize = CGSize(width: scene.width, height: scene.height)
            field.viewport.viewSize = field.bounds.size; field.viewport.zoom = 3
            field.viewport.scrollX = Double(classic.configuration.entrances.first?.x ?? 0) - 140
            field.viewport.clamp()
        }),
        try { let (view, draw) = try c2.makeField(); return (c2.initial, view, draw) }(),
        try { let (view, draw) = try c3.makeField(); return (c3.initial, view, draw) }()
    ]
    let output = URL(fileURLWithPath: ".build/hot-seat-ghosts/screens")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for (initial, view, render) in contexts {
        let replay = try validateHotSeatGhosts(initial: initial)
        try validateStoreGhosts(initial: initial, replay: replay)
        var live = initial
        for _ in 0..<100 { live.step() }
        let liveHash = try live.hash()
        view.frame = CGRect(x: 0, y: 0, width: 1120, height: 640)
        render(live)
        func setGhosts(_ playback: HotSeatGhostPlayback?) {
            (view as? HotSeatGhostRendering)?.hotSeatGhosts = playback
        }
        func capture(_ name: String) throws -> Data {
            view.needsDisplay = true
            let image = ReplayFrameCapture.image(size: view.bounds.size) {
                ReplayFrameCapture.draw(view, in: view.bounds)
            }!
            let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            try data.write(to: output.appendingPathComponent(initial.engine + "-" + name + ".png"))
            return data
        }
        let inputViews = view.subviews.map(ObjectIdentifier.init)
        func moviePixels() -> Data? {
            guard let image = ReplayFrameCapture.image(size: view.bounds.size, draw: {
                ReplayFrameCapture.draw(view, in: view.bounds)
            }), let data = image.dataProvider?.data else { return nil }
            return data as Data
        }
        let plain = try capture("plain")
        let plainMovie = moviePixels()
        for colour in [ReplayGhostColour.blue, .pink, .orange] {
            setGhosts(.init(attempts: [.init(playerID: "previous", colour: colour, replay: replay)], initial: initial))
            let visible = try capture("ghost-\(colour.rawValue)")
            try checkGhost(visible != plain, "\(initial.engine) ghost did not render")
            try checkGhost(moviePixels() != plainMovie, "Movie capture omitted ghosts")
        }
        setGhosts(.init(attempts: [.init(playerID: "one", colour: .blue, replay: replay),
                                 .init(playerID: "two", colour: .pink, replay: replay)], initial: initial))
        _ = try capture("two-players")
        try checkGhost(try live.hash() == liveHash, "Render changed the live engine")
        // Ghost rendering adds no view or input target.
        try checkGhost(view.subviews.map(ObjectIdentifier.init) == inputViews, "Ghost added an input surface")
        print("PASS \(initial.engine): native sprite colours and unchanged input surface")
    }
    let colours = ReplayGhostColour.allCases.map { SolutionGhostPixels(rgba: Data([255, 255, 255, 255]),
        width: 1, height: 1, colour: $0).rgba }
    try checkGhost(Set(colours).count == 8, "Roster colours are not distinct")
}

@MainActor func fieldImage(_ scene: ClassicRenderedLevel, terrain: ClassicDOSTerrain) -> CGImage? {
    let rgba = ClassicSceneFrame.terrainRGBA(scene, terrain: terrain)
    guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
    return CGImage(width: scene.width, height: scene.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: scene.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
do { try MainActor.assumeIsolated { try runGhostChecks() }; print("Hot Seat ghost checks passed") }
catch { fputs("FAIL \(error)\n", stderr); exit(1) }
