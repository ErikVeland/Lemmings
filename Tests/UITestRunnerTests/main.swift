import AppKit
import AVFoundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAILED: \(message)\n", stderr); exit(1) }
}

@MainActor private final class RedCanvas: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.setFill()
        bounds.fill()
    }
}

@MainActor private final class Actions: NSObject {
    var count = 0
    @objc func press() { count += 1 }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
let mode = ProcessInfo.processInfo.environment["LEMMINGS_TEST_WINDOWS"] ?? "offscreen"

@MainActor private func verifyPlacement(_ window: NSWindow, expectsOffscreen: Bool = false) {
    let screens = NSScreen.screens
    if mode == "secondary", screens.count > 1, !expectsOffscreen {
        require(screens[1].visibleFrame.contains(window.frame), "Window escaped the second display: \(window.frame)")
        require(!screens[0].frame.intersects(window.frame), "Window covered the primary display")
    } else {
        require(!screens.contains { $0.frame.intersects(window.frame) }, "Window appeared on a display: \(window.frame)")
    }
    require(window.isVisible, "Offscreen placement changed AppKit ordering state")
}

@MainActor private func verifySilentAudio() throws {
    require(ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted", "Mechanical tests must default to muted audio")
    // Fixtures contain only silence, even if a regression disables the guard.
    var wav = Data("RIFF".utf8)
    func word(_ value: UInt32, bytes: Int) {
        for byte in 0..<bytes { wav.append(UInt8(truncatingIfNeeded: value >> (8 * byte))) }
    }
    word(196, bytes: 4); wav.append(Data("WAVEfmt ".utf8))
    word(16, bytes: 4); word(1, bytes: 2); word(1, bytes: 2)
    word(8000, bytes: 4); word(16000, bytes: 4); word(2, bytes: 2); word(16, bytes: 2)
    wav.append(Data("data".utf8)); word(160, bytes: 4); wav.append(Data(repeating: 0, count: 160))
    let sound = NSSound(data: wav)!
    sound.volume = 1
    require(sound.volume == 0, "Sound effects can escape mute")
    sound.play(); sound.volume = 0.8
    require(sound.volume == 0, "Playing sound effects can restore volume")
    sound.stop()
    let audio = try AVAudioPlayer(data: wav)
    audio.volume = 1; audio.play()
    audio.setVolume(0.8, fadeDuration: 0.1)
    require(audio.volume == 0, "Music can escape mute through a fade")
    audio.stop()
    let replay = AVPlayer()
    replay.volume = 1; replay.isMuted = false; replay.play()
    require(replay.isMuted && replay.volume == 0, "Replay audio can escape mute")
    replay.pause()
    let engine = AVAudioEngine()
    let source = AVAudioSourceNode { _, _, _, buffers in
        for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }
        return noErr
    }
    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!)
    engine.mainMixerNode.outputVolume = 1
    try engine.start()
    engine.mainMixerNode.outputVolume = 0.75
    require(engine.isRunning && engine.mainMixerNode.outputVolume == 0,
        "Engine mute stopped playback clocks or let output volume return")
    engine.stop()
    print("PASS silent music, sound effects, replay audio and engine output; volume changes cannot unmute tests")
}

Task { @MainActor in
    if CommandLine.arguments.contains("--activate") {
        app.activate(ignoringOtherApps: true)
        exit(1) // Quiet runs must reject activation instead of claiming a focus check passed.
    }
    do { try verifySilentAudio() }
    catch { fputs("FAILED: silent audio checks: \(error)\n", stderr); exit(1) }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
        styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    let canvas = RedCanvas(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    let actions = Actions()
    let button = NSButton(title: "Test", target: actions, action: #selector(Actions.press))
    button.frame = CGRect(x: 20, y: 20, width: 80, height: 30)
    canvas.addSubview(button)
    window.contentView = canvas
    window.center()
    window.makeKeyAndOrderFront(nil)
    verifyPlacement(window)
    window.setFrameOrigin(.zero)
    window.setContentSize(CGSize(width: 500, height: 350))
    window.displayIfNeeded()
    verifyPlacement(window)
    require(canvas.hitTest(CGPoint(x: 40, y: 30)) === button, "Button hit target moved")
    require(window.makeFirstResponder(button) && window.firstResponder === button, "Responder focus failed")
    button.performClick(nil)
    require(actions.count == 1, "Button action failed")
    let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds)!
    canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
    require(bitmap.colorAt(x: 200, y: 150)!.usingColorSpace(.deviceRGB)!.redComponent > 0.9,
        "Offscreen bitmap lost its rendered content")
    try? await Task.sleep(nanoseconds: 300_000_000)
    var captured = bitmap
    if mode == "secondary" {
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow,
            CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) else {
            fputs("FAILED: No composited capture\n", stderr); exit(1)
        }
        captured = NSBitmapImageRep(cgImage: image)
        require(captured.colorAt(x: 200, y: 150)!.usingColorSpace(.deviceRGB)!.redComponent > 0.9,
            "Window capture lost its rendered content")
    }
    let output = URL(fileURLWithPath: ".build/ui-test-runner/\(mode).png")
    do { try captured.representation(using: .png, properties: [:])!.write(to: output) }
    catch { fputs("FAILED: \(error)\n", stderr); exit(1) }

    let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 200, height: 100),
        styleMask: [.titled], backing: .buffered, defer: false)
    window.addChildWindow(panel, ordered: .above)
    panel.orderFront(nil)
    verifyPlacement(panel)
    window.removeChildWindow(panel)
    panel.orderOut(nil)
    window.orderOut(nil)
    require(!window.isVisible, "Ordering out no longer works")
    window.orderFrontRegardless()
    verifyPlacement(window)
    // Preserve large render fixtures without spilling onto the player's screen.
    let width = (NSScreen.screens.map { $0.frame.width }.max() ?? 0) + 100
    window.setContentSize(CGSize(width: width, height: 100))
    verifyPlacement(window, expectsOffscreen: true)
    if mode == "offscreen" {
        require(!app.isActive && NSWorkspace.shared.frontmostApplication?.processIdentifier == front,
            "Background test stole desktop focus")
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        require(!windows.contains { ($0[kCGWindowOwnerPID as String] as? Int32) == ProcessInfo.processInfo.processIdentifier },
            "Background test left a window on the desktop")
    }
    window.orderOut(nil)
    print("PASS \(mode): window/panel placement, resizing, input, responder focus and captures")
    exit(0)
}
app.run()
