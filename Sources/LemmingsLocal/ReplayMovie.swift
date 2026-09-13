import AppKit
@preconcurrency import AVFoundation
import NxlvKit
import UniformTypeIdentifiers

enum ReplayStorage {
  static let directory: URL = {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("UltimateLemmingsReplays", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let entries = (try? FileManager.default.contentsOfDirectory(at: folder,
      includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])) ?? []
    for entry in entries {
      guard let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
        values.isRegularFile == true, let date = values.contentModificationDate,
        Date().timeIntervalSince(date) > 86400 else { continue }
      try? FileManager.default.removeItem(at: entry)
    }
    return folder
  }()
}

/// Records game ticks on a serial encoder queue. Playback never touches the game.
final class ReplayMovieRecorder: @unchecked Sendable {
  let url: URL
  private let queue: DispatchQueue
  private let admissionTimeout: DispatchTimeInterval
  private let ticksPerSecond: Int32
  private var writer: AVAssetWriter?
  private var video: AVAssetWriterInput?
  private var audioFile: AVAudioFile?
  private var videoURL: URL { url.deletingPathExtension().appendingPathExtension("video.mp4") }
  private var audioURL: URL { url.deletingPathExtension().appendingPathExtension("audio.m4a") }
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var frameCount: Int64 = 0
  private var audioFrames: Int64 = 0
  private var storedFailure: String?
  private var failure: String? {
    get { cancellationLock.lock(); defer { cancellationLock.unlock() }; return storedFailure }
    set { cancellationLock.lock(); if storedFailure == nil { storedFailure = newValue }; cancellationLock.unlock() }
  }
  private var finished = false
  private var size = CGSize.zero
  private var sounds: [Voice] = []
  private var music: ReplayMusic?
  private var oldMusic: ReplayMusic?
  private var musicURL: URL?
  private var musicGain: Float = 0
  private var fadeFrames = 0
  private let cancellationLock = NSLock()
  private var discarded = false
  private var submissionClosed = false
  private var isDiscarded: Bool { cancellationLock.lock(); defer { cancellationLock.unlock() }; return discarded }
  var isAcceptingFrames: Bool {
    cancellationLock.lock(); defer { cancellationLock.unlock() }
    return !discarded && !submissionClosed && storedFailure == nil
  }
  private let admission = DispatchSemaphore(value: 12)
  #if PERFORMANCE_TESTS
  var recordingFailure: String? { failure }
  private let metricLock = NSLock()
  private var admissionWait = 0.0
  var admissionWaitSeconds: Double { metricLock.lock(); defer { metricLock.unlock() }; return admissionWait }
  #endif

  private struct Voice {
    let samples: [Float]
    let step: Double
    let gain: Float
    var position = 0.0
  }

  init(ticksPerSecond: Double, encodingQueue: DispatchQueue? = nil,
       admissionTimeout: DispatchTimeInterval = .milliseconds(500)) {
    queue = encodingQueue ?? DispatchQueue(label: "academy.glasscode.lemmings.replay", qos: .utility)
    self.admissionTimeout = admissionTimeout
    self.ticksPerSecond = Int32((max(1, min(1000, ticksPerSecond.isFinite ? ticksPerSecond : 17)) * 1000).rounded())
    url = ReplayStorage.directory.appendingPathComponent("lemmings-replay-\(UUID().uuidString).mp4")
  }

  func sound(samples: [Float], rate: Double, gain: Float) {
    guard isAcceptingFrames else { return }
    queue.async { [self] in
      guard !finished, failure == nil, sounds.count < 32, !samples.isEmpty else { return }
      sounds.append(Voice(samples: samples, step: rate / 44100, gain: gain))
    }
  }

  func setMusic(url: URL?, gain: Float) {
    guard isAcceptingFrames else { return }
    queue.async { [self] in
      guard !finished, failure == nil else { return }
      musicGain = gain
      guard url != musicURL else { return }
      oldMusic = music
      music = url.flatMap { try? ReplayMusic(url: $0) }
      musicURL = url
      fadeFrames = oldMusic == nil ? 0 : 114660
    }
  }

  /// Stop a stalled recording instead of blocking game input or dropping movie frames.
  func append(_ image: CGImage) {
    guard isAcceptingFrames else { return }
    #if PERFORMANCE_TESTS
    let waitingSince = ProcessInfo.processInfo.systemUptime
    #endif
    let admitted = admission.wait(timeout: .now() + admissionTimeout) == .success
    #if PERFORMANCE_TESTS
    metricLock.lock(); admissionWait += ProcessInfo.processInfo.systemUptime - waitingSince; metricLock.unlock()
    #endif
    guard admitted else {
      failure = "Replay recording stopped because the encoder stalled."
      return
    }
    queue.async { [self] in
      defer { admission.signal() }
      guard !finished, failure == nil else { return }
      autoreleasepool {
        do {
          if writer == nil { try begin(image) }
          try write(image)
        } catch { failure = error.localizedDescription; writer?.cancelWriting() }
      }
    }
  }

  func finish(_ completion: @escaping @MainActor @Sendable (Result<URL, ReplayMovieError>) -> Void) {
    cancellationLock.lock(); submissionClosed = true; cancellationLock.unlock()
    if let failure {
      Task { @MainActor in completion(.failure(.message(failure))) }
      queue.async { [self] in
        finished = true
        if writer?.status == .writing { writer?.cancelWriting() }
        audioFile = nil
        for file in [url, videoURL, audioURL] { try? FileManager.default.removeItem(at: file) }
      }
      return
    }
    queue.async { [self] in
      guard !finished else {
        let result: Result<URL, ReplayMovieError> = failure.map { .failure(.message($0)) } ?? .success(url)
        Task { @MainActor in completion(result) }
        return
      }
      finished = true
      guard let writer, frameCount > 0, failure == nil else {
        if writer?.status == .writing { writer?.cancelWriting() }
        let error = ReplayMovieError.message(failure ?? "This run has no replay frames yet.")
        Task { @MainActor in completion(.failure(error)) }
        return
      }
      writer.endSession(atSourceTime: CMTime(value: frameCount * 1000, timescale: ticksPerSecond))
      video?.markAsFinished(); audioFile = nil
      writer.finishWriting { [self] in
        guard self.writer?.status == .completed else {
          let error = ReplayMovieError.message(self.writer?.error?.localizedDescription ?? "The replay could not be saved.")
          Task { @MainActor in completion(.failure(error)) }
          return
        }
        Task { @MainActor in
          do {
            try await Self.mux(video: videoURL, audio: audioURL, destination: url)
            if isDiscarded { try? FileManager.default.removeItem(at: url) }
            else { completion(.success(url)) }
          } catch { completion(.failure(.message(error.localizedDescription))) }
          try? FileManager.default.removeItem(at: videoURL)
          try? FileManager.default.removeItem(at: audioURL)
        }
      }
    }
  }

  func discard() {
    cancellationLock.lock(); discarded = true; cancellationLock.unlock()
    queue.async { [self] in
      finished = true
      if writer?.status == .writing { writer?.cancelWriting() }
      audioFile = nil
      for file in [url, videoURL, audioURL] { try? FileManager.default.removeItem(at: file) }
    }
  }

  private func begin(_ image: CGImage) throws {
    let width = image.width / 2 * 2, height = image.height / 2 * 2
    guard width > 0, height > 0 else { throw ReplayMovieError.message("The replay frame is empty.") }
    size = CGSize(width: width, height: height)
    let made = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000,
        AVVideoMaxKeyFrameIntervalKey: Int(ticksPerSecond / 1000), AVVideoAllowFrameReorderingKey: false]])
    input.expectsMediaDataInRealTime = false
    guard made.canAdd(input) else { throw ReplayMovieError.message("Movie encoding is unavailable.") }
    made.add(input)
    audioFile = try AVAudioFile(forWriting: audioURL, settings: [
      AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128000])
    adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
      kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
    guard made.startWriting() else { throw ReplayMovieError.message(made.error?.localizedDescription ?? "Movie writing could not start.") }
    made.startSession(atSourceTime: .zero)
    writer = made; video = input
  }

  private func ready(_ input: AVAssetWriterInput) throws {
    let deadline = ProcessInfo.processInfo.systemUptime + 10
    while !input.isReadyForMoreMediaData {
      guard failure == nil, !isDiscarded, writer?.status == .writing, ProcessInfo.processInfo.systemUptime < deadline else {
        throw ReplayMovieError.message(failure ?? writer?.error?.localizedDescription ?? "The movie encoder stopped responding.")
      }
      Thread.sleep(forTimeInterval: 0.002)
    }
    if let failure { throw ReplayMovieError.message(failure) }
  }

  private func write(_ image: CGImage) throws {
    guard let video, let audioFile, let adaptor, let pool = adaptor.pixelBufferPool else {
      throw ReplayMovieError.message("The movie encoder has no frame buffer.")
    }
    try ready(video)
    var pixelBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
      let pixelBuffer else { throw ReplayMovieError.message("The replay frame could not be allocated.") }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: Int(size.width),
      height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
      throw ReplayMovieError.message("The replay frame could not be drawn.")
    }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(origin: .zero, size: size))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: frameCount * 1000, timescale: ticksPerSecond)) else {
      throw ReplayMovieError.message(writer?.error?.localizedDescription ?? "A replay frame could not be encoded.")
    }
    let end = (frameCount + 1) * 44100 * 1000 / Int64(ticksPerSecond)
    let count = Int(end - audioFrames)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(count)),
      let channels = buffer.floatChannelData else { throw ReplayMovieError.message("Replay audio could not be buffered.") }
    buffer.frameLength = AVAudioFrameCount(count)
    if sounds.isEmpty && music == nil && oldMusic == nil {
      channels[0].update(repeating: 0, count: count)
      channels[1].update(repeating: 0, count: count)
    } else {
      for i in 0..<count {
        var effect: Float = 0
        for j in sounds.indices {
          let position = Int(sounds[j].position)
          if position < sounds[j].samples.count {
            effect += sounds[j].samples[position] * sounds[j].gain
            sounds[j].position += sounds[j].step
          }
        }
        let current = music?.nextFrame() ?? (0, 0)
        var left = current.0, right = current.1
        if fadeFrames > 0 {
          let old = oldMusic?.nextFrame() ?? (0, 0)
          let mix = Float(1 - Double(fadeFrames) / 114660)
          let incoming = sin(mix * .pi / 2), outgoing = cos(mix * .pi / 2)
          left = current.0 * incoming + old.0 * outgoing
          right = current.1 * incoming + old.1 * outgoing
          fadeFrames -= 1
          if fadeFrames == 0 { oldMusic = nil }
        }
        channels[0][i] = max(-1, min(1, effect + left * musicGain))
        channels[1][i] = max(-1, min(1, effect + right * musicGain))
      }
      sounds.removeAll { Int($0.position) >= $0.samples.count }
    }
    try audioFile.write(from: buffer)
    audioFrames = end; frameCount += 1
  }
  @MainActor private static func mux(video: URL, audio: URL, destination: URL) async throws {
    let picture = AVURLAsset(url: video), sound = AVURLAsset(url: audio)
    let duration = try await picture.load(.duration)
    let composition = AVMutableComposition()
    for (asset, type) in [(picture, AVMediaType.video), (sound, AVMediaType.audio)] {
      guard let source = try await asset.loadTracks(withMediaType: type).first,
        let track = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw ReplayMovieError.message("The replay is missing a media track.")
      }
      let sourceDuration = try await asset.load(.duration)
      try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, sourceDuration)), of: source, at: .zero)
    }
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
      throw ReplayMovieError.message("The replay could not be assembled.")
    }
    exporter.outputURL = destination; exporter.outputFileType = .mp4
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      exporter.exportAsynchronously { continuation.resume() }
    }
    guard exporter.status == .completed else { throw ReplayMovieError.message(exporter.error?.localizedDescription ?? "The replay could not be assembled.") }
  }

}

enum ReplayMovieError: LocalizedError, Sendable {
  case message(String)
  var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

/// Streams a recording or synthesizes a module for the replay's game clock.
private final class ReplayMusic {
  private var module: ProTrackerEnhancedPlayer?
  private var moduleData: ProTrackerModule?
  private var file: AVAudioFile?
  private var buffer: AVAudioPCMBuffer?
  private var position = 0.0
  private var step = 1.0
  init(url: URL) throws {
    if url.pathExtension.lowercased() == "mod" {
      let data = try ProTrackerModule(data: Data(contentsOf: url))
      moduleData = data
      module = ProTrackerEnhancedPlayer(module: data, sampleRate: 44100, enhancements: .faithful)
    } else {
      let source = try AVAudioFile(forReading: url)
      file = source
      buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 4096)
      step = source.processingFormat.sampleRate / 44100
      try refill()
    }
  }
  private func refill() throws {
    guard let file, let buffer else { return }
    if file.framePosition >= file.length { file.framePosition = 0 }
    try file.read(into: buffer)
  }
  func nextFrame() -> (Float, Float) {
    if module != nil {
      let sample = module!.nextFrame()
      if module!.hasFinished, let moduleData {
        module = ProTrackerEnhancedPlayer(module: moduleData, sampleRate: 44100, enhancements: .faithful)
      }
      return (sample.left, sample.right)
    }
    guard let buffer, let data = buffer.floatChannelData else { return (0, 0) }
    if position >= Double(buffer.frameLength) {
      position -= Double(buffer.frameLength)
      try? refill()
    }
    guard buffer.frameLength > 0 else { return (0, 0) }
    let index = min(Int(buffer.frameLength) - 1, Int(position))
    position += step
    return (data[0][index], data[buffer.format.channelCount > 1 ? 1 : 0][index])
  }
}

@MainActor enum ReplayFrameCapture {
  /// Draw a game surface at a fixed movie resolution without resizing the live view.
  static func image(size: CGSize, draw: () -> Void) -> CGImage? {
    let width = Int(size.width) / 2 * 2, height = Int(size.height) / 2 * 2
    guard width > 0, height > 0, let context = CGContext(data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()
  }
  static func draw(_ view: NSView, in rect: CGRect) {
    guard view.bounds.width > 0, view.bounds.height > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    transform.scaleX(by: rect.width / view.bounds.width, yBy: rect.height / view.bounds.height)
    transform.concat()
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
  }
}
