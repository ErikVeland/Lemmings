import AVFoundation
import CoreGraphics
import Testing
import LemmingsAppCore

struct ReplayMovieTimingTests {
    @MainActor @Test func heldImagesKeepTheFullMovieAndAudioDuration() async throws {
        let rate = 23.0
        let recorder = ReplayMovieRecorder(ticksPerSecond: rate, admissionTimeout: .seconds(5))
        defer { recorder.discard() }
        let context = try #require(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        for group in 0..<3 {
            context.setFillColor(gray: CGFloat(group) / 2, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            let image = try #require(context.makeImage())
            recorder.append(image)
            for _ in 1..<23 { recorder.append(image, reusesImage: true) }
        }
        let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            recorder.finish { continuation.resume(with: $0.mapError { $0 as Error }) }
        }
        let (duration, audioDuration) = try await Self.movieDurations(at: url)
        #expect(abs(duration - 3) < 0.02)
        #expect(abs(audioDuration - 3) < 0.07)
        #expect(recorder.encodingProfile.encodedFrames == 69)
        #expect(recorder.encodingProfile.videoSamples == 4)
    }

    // Keep AVFoundation's non-Sendable tracks off the main actor on older SDKs.
    private static func movieDurations(at url: URL) async throws -> (Double, Double) {
        let movie = AVURLAsset(url: url)
        let duration = try await movie.load(.duration).seconds
        let tracks = try await movie.loadTracks(withMediaType: .audio)
        let audio = try #require(tracks.first)
        return (duration, try await audio.load(.timeRange).duration.seconds)
    }
}
