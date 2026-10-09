import AppKit
import AVFoundation
import NxlvKit

func require(_ value: Bool, _ message: String) throws {
  if !value { throw ReplayMovieError.message(message) }
}

@MainActor func verifyStalledRecording() async throws {
  let encoder = DispatchQueue(label: "ReplayMovieTests.stalled")
  let release = DispatchSemaphore(value: 0)
  encoder.async { release.wait() }
  defer { release.signal() }
  let recorder = ReplayMovieRecorder(ticksPerSecond: 17, encodingQueue: encoder,
    admissionTimeout: .milliseconds(10))
  let frame = ReplayFrameCapture.image(size: CGSize(width: 16, height: 16)) {
    NSColor.black.setFill(); NSRect(x: 0, y: 0, width: 16, height: 16).fill()
  }!
  for _ in 0..<12 { recorder.append(frame) }
  let began = ProcessInfo.processInfo.systemUptime
  recorder.append(frame)
  let blocked = ProcessInfo.processInfo.systemUptime - began
  let stopped = !recorder.isAcceptingFrames
  for _ in 0..<100 { recorder.append(frame); recorder.setMusic(url: nil, gain: 0) }
  let elapsed = ProcessInfo.processInfo.systemUptime - began
  try require(stopped && blocked < 1 && elapsed < 1,
    "A stalled encoder blocked game input or kept accepting frames")
  let result = await withCheckedContinuation { continuation in
    recorder.finish { continuation.resume(returning: $0) }
  }
  guard case let .failure(.message(message)) = result, message.contains("encoder stalled") else {
    throw ReplayMovieError.message("A stalled recorder offered an incomplete movie")
  }
  recorder.discard()

  let run = RunMovie()
  var draws = 0
  run.capture({ draws += 1; return frame }())
  run.useTestRecorder(recorder)
  run.capture({ draws += 1; return frame }())
  run.begin(ticksPerSecond: 17, title: "Lazy capture")
  run.capture({ draws += 1; return frame }())
  run.finish()
  run.capture({ draws += 1; return frame }())
  run.discard()
  run.capture({ draws += 1; return frame }())
  try require(draws == 1, "Inactive, failed, finishing or discarded runs still drew replay frames")
  print("PASS stalled encoding preserves input responsiveness, rejects partial movies and stops unused capture work")
}

extension RunMovie {
  fileprivate func useTestRecorder(_ recorder: ReplayMovieRecorder) { self.recorder = recorder }
}

@MainActor func verifyMovie() async throws {
  let recorder = ReplayMovieRecorder(ticksPerSecond: 17)
  let tone = (0..<11025).map { Float(sin(Double($0) * 2 * .pi * 900 / 44100) * 0.4) }
  let module = URL(fileURLWithPath: "Sources/Music/lemmings_2_music_mod_tsyu/endtune.mod")
  recorder.setMusic(url: module, gain: 0.25)
  let start = ProcessInfo.processInfo.systemUptime
  for frame in 0..<51 {
    if frame.isMultiple(of: 17) { recorder.sound(samples: tone, rate: 44100, gain: 0.5) }
    let image = ReplayFrameCapture.image(size: CGSize(width: 640, height: 400)) {
      NSColor.black.setFill(); NSRect(x: 0, y: 0, width: 640, height: 400).fill()
      NSColor.red.setFill(); NSRect(x: frame * 8, y: 20, width: 40, height: 40).fill()
      NSColor.green.setFill(); NSRect(x: 0, y: 320, width: 640, height: 80).fill()
    }!
    recorder.append(image)
  }
  let url = try await withCheckedThrowingContinuation { (c: CheckedContinuation<URL, Error>) in
    recorder.finish { c.resume(with: $0.mapError { $0 as Error }) }
  }
  let root = URL(fileURLWithPath: ".build/replay-movie-tests")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let original = root.appendingPathComponent("sample.mp4")
  try? FileManager.default.removeItem(at: original)
  try FileManager.default.copyItem(at: url, to: original)
  let asset = AVURLAsset(url: url)
  let duration = try await asset.load(.duration)
  try require(abs(duration.seconds - 3) < 0.03, "Recording lost ticks: \(duration.seconds)")
  let tracks = try await asset.loadTracks(withMediaType: .video)
  try require(tracks.count == 1, "Video missing")
  let reader = try AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: tracks[0], outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  reader.add(output); reader.startReading()
  var count = 0
  while let sample = output.copyNextSampleBuffer() {
    if count == 0, let buffer = CMSampleBufferGetImageBuffer(sample) {
      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
      let stride = CVPixelBufferGetBytesPerRow(buffer)
      try require(bytes[40 * stride + 20 * 4 + 2] > 180, "Movie was vertically flipped or lost its red frame")
      try require(bytes[350 * stride + 20 * 4 + 1] > 150, "Movie lost its bottom control bar")
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    }
    count += 1
  }
  try require(count == 51 && reader.status == .completed, "Movie dropped game ticks: \(count)")
  let sound = try AVAudioFile(forReading: url)
  let buffer = AVAudioPCMBuffer(pcmFormat: sound.processingFormat, frameCapacity: 44100)!
  try sound.read(into: buffer)
  let peak = (0..<Int(buffer.frameLength)).map { abs(buffer.floatChannelData![0][$0]) }.max() ?? 0
  try require(peak > 0.1, "Recorded effects and music are silent")
  for speed: Float in [0.5, 2] {
    let destination = root.appendingPathComponent("sample-\(speed)x.mp4")
    try? FileManager.default.removeItem(at: destination)
    try await ReplayMovieWindow.export(source: url, destination: destination, speed: speed)
    let exported = AVURLAsset(url: destination)
    let exportedDuration = try await exported.load(.duration)
    try require(abs(exportedDuration.seconds - 3 / Double(speed)) < 0.1, "Export speed is wrong: \(exportedDuration.seconds)")
    let audio = try await exported.loadTracks(withMediaType: .audio)
    try require(audio.count == 1, "Speed export lost audio")
  }
  print("PASS 51 exact video ticks, upright frames, non-silent module/SFX audio, half/double-speed exports; \(String(format: "%.2f", ProcessInfo.processInfo.systemUptime - start))s")
  for fps in [17.5, 23.0] {
    let fractional = ReplayMovieRecorder(ticksPerSecond: fps)
    let image = ReplayFrameCapture.image(size: CGSize(width: 64, height: 48)) {
      NSColor.green.setFill(); NSRect(x:0,y:0,width:64,height:48).fill()
    }!
    for _ in 0..<Int(fps * 2) { fractional.append(image) }
    let result = try await withCheckedThrowingContinuation { (c: CheckedContinuation<URL, Error>) in
      fractional.finish { c.resume(with: $0.mapError { $0 as Error }) }
    }
    let duration = try await AVURLAsset(url: result).load(.duration)
    try require(abs(duration.seconds - 2) < 0.01, "The \(fps) Hz replay clock drifted: \(duration.seconds)")
    fractional.discard()
  }
  print("PASS exact 17.5 Hz L2 and 23 Hz L3 movie clocks")
  recorder.discard()
}

@MainActor func verifyDirectionalGhostMovie() async throws {
  let live = SpeedTrails(), movie = SpeedTrails()
  let recorder = ReplayMovieRecorder(ticksPerSecond: 17)
  let size = CGSize(width: 640, height: 320)
  let sprite = NSImage(cgImage: ReplayFrameCapture.image(size: CGSize(width: 16, height: 20)) {
    NSColor.green.setFill(); CGRect(x: 0, y: 0, width: 16, height: 20).fill()
  }!, size: CGSize(width: 16, height: 20))
  var position = CGPoint(x: 100, y: 100)
  var expected: [(CGRect, CGVector)] = []
  func render(_ trails: SpeedTrails, rect: CGRect) -> CGImage {
    ReplayFrameCapture.image(size: size) {
      NSColor.black.setFill(); CGRect(origin: .zero, size: size).fill()
      trails.draw(enabled: true, in: CGRect(origin: .zero, size: size)) {
        trails.drawBehind(actor: 1, sprite: sprite, in: rect, motion: trails.motion(actor: 1),
          pixelSize: CGSize(width: 2, height: 2))
        sprite.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
      }
    }!
  }
  for tick in 0..<41 {
    let movement: String
    if tick == 0 { movement = "walking" }
    else if tick <= 10 { position.x += 3; position.y -= tick.isMultiple(of: 2) ? 0 : 1; movement = "walking" }
    else if tick <= 20 { position.x -= 3; movement = "walking" }
    else if tick <= 30 { position.y += 2; movement = "falling" }
    else { position.y -= 2; movement = "climbing" }
    let actor = SpeedTrails.Actor(id: 1, position: position, movement: movement)
    live.update(tick: tick, enabled: true, actors: [actor])
    movie.update(tick: tick, enabled: true, actors: [actor])
    // Camera and animation anchors move independently of the actor's world position.
    let rect = CGRect(x: 290 + tick % 3 * 2, y: 135 + tick % 2 * 2, width: 32, height: 40)
    let frame = render(movie, rect: rect)
    if tick.isMultiple(of: 3) {
      let displayed = render(live, rect: rect)
      try require((displayed.dataProvider!.data! as Data) == (frame.dataProvider!.data! as Data),
        "Live and replay ghosts diverged at tick \(tick)")
      try require((render(movie, rect: rect).dataProvider!.data! as Data) == (frame.dataProvider!.data! as Data),
        "A repeated capture changed the ghost direction")
    }
    expected.append((rect, movie.motion(actor: 1)))
    recorder.append(frame)
  }
  let url = try await withCheckedThrowingContinuation { (c: CheckedContinuation<URL, Error>) in
    recorder.finish { c.resume(with: $0.mapError { $0 as Error }) }
  }
  let asset = AVURLAsset(url: url)
  let track = try await asset.loadTracks(withMediaType: .video)[0]
  let reader = try AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: track,
    outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  reader.add(output); reader.startReading()
  var count = 0
  while let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample) {
    try require(count < expected.count, "Ghost recording gained frames")
    let (rect, motion) = expected[count]
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    var weight = 0.0, dx = 0.0, dy = 0.0
    for y in 75..<235 { for x in 225..<385 {
      guard !rect.insetBy(dx: -3, dy: -3).contains(CGPoint(x: x, y: y)) else { continue }
      let offset = y * stride + x * 4
      let energy = Double(max(0, Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2]) - 24))
      weight += energy
      dx += (Double(x) - rect.midX) * energy
      dy += (Double(y) - rect.midY) * energy
    } }
    CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    if motion != .zero {
      let dot = dx * motion.dx + dy * motion.dy
      let cross = dx * motion.dy - dy * motion.dx
      try require(weight > 0 && dot < 0 && abs(cross) < abs(dot) * 0.7,
        "Encoded ghost lost its direction at tick \(count): \(dx),\(dy), motion \(motion)")
    }
    count += 1
  }
  try require(count == expected.count && reader.status == .completed, "Ghost recording dropped game ticks")
  let preview = URL(fileURLWithPath: ".build/replay-movie-tests/directional-ghosts.mp4")
  try? FileManager.default.removeItem(at: preview)
  try FileManager.default.copyItem(at: url, to: preview)
  recorder.discard()
  print("PASS encoded directional ghosts: all 41 frames, slopes, reversal, fall, climb, camera shifts and unequal live/replay render cadence")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
  do {
    try await verifyStalledRecording()
    try await verifyMovie()
    try await verifyDirectionalGhostMovie()
    try await ReplayMovieWindow.shared.checkControls(URL(fileURLWithPath: ".build/replay-movie-tests/sample.mp4"))
    exit(0)
  }
  catch { print("FAIL: \(error)"); exit(1) }
}
app.run()

extension ReplayMovieWindow {
  fileprivate func checkControls(_ url: URL) async throws {
    let host = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
    host.contentView = NSView()
    GameScreen.shared.gameWindow = host
    let windowCount = NSApp.windows.count
    player.isMuted = true
    var opened = 0, closed = 0
    open(url, title: "Test replay", onOpen: { opened += 1 }, onClose: { closed += 1 })
    for _ in 0..<50 {
      if player.currentItem?.status == .readyToPlay { break }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    try require(player.currentItem?.status == .readyToPlay && duration > 0, "Saved movie did not become playable")
    try require(opened == 1, "Replay did not suspend the game audio")
    bar.onAction?(.slower)
    try require(playbackRate == 0.5, "Slower button did not select half speed")
    bar.onAction?(.slower)
    try require(playbackRate == 0.25, "Quarter speed is unavailable")
    for _ in 0..<8 { bar.onAction?(.faster) }
    try require(playbackRate == 8, "Fast replay did not stop at 8x")
    bar.onAction?(.play)
    try require(player.rate == 0, "Replay pause did not stop playback")
    let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: ".build/local/Ultimate Lemmings.app/Contents/Resources/MacArtwork/lemmings"))
    bar.useTestArtwork(artwork)
    bar.frame.size = CGSize(width: 1120, height: 154)
    refresh()
    let image = ReplayFrameCapture.image(size: bar.bounds.size) { bar.draw(bar.bounds) }!
    let bitmap = NSBitmapImageRep(cgImage: image)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: ".build/replay-movie-tests/controls.png"))
    try require(root.window === host && NSApp.windows.count == windowCount, "Replay created a separate window")
    close()
    try require(closed == 1, "Replay did not restore the game audio on close")
    print("PASS game-font replay controls, 0.25x through 8x speeds, pause and source-audio lifecycle")
  }
}
extension ReplayBar {
  fileprivate func useTestArtwork(_ artwork: ClassicMacArtwork) { font = ClassicMacUserInterface(artwork: artwork).map(MacInterfaceRenderer.init(interface:)) }
}
