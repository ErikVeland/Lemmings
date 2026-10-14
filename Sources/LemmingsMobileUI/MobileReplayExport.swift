#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileGameViewController {
    /// Draws a separate replay at the current camera position for the share sheet.
    func shareReplayMovie(document: Data) {
        let recorder = ReplayMovieRecorder(ticksPerSecond: session.ticksPerSecond)
        let viewport = playfieldView.gameViewport
        let cancelled = MobileReplayExportCancellation()
        showCustomOverlay(title: "Replay movie", details: [], actions: [("CANCEL", { [weak self] in
            cancelled.cancelled = true
            recorder.discard()
            self?.returnToResult()
        })])
        Task { @MainActor [weak self] in
            guard let self else { recorder.discard(); return }
            do {
                guard let replay = try self.session.makeReplaySession(document: document) else {
                    throw MobileSessionError.unsupportedControl
                }
                recorder.setMusic(url: MobileMusic.shared.currentTrackURL, gain: Float(MobileSettings.load(from: .standard).classic.musicVolume))
                let movieEffects = effects.movieEffects()
                let expected = try JSONDecoder().decode(ClassicDOSReplay.self, from: document).expected?.ticks
                repeat {
                    guard !cancelled.cancelled else { return }
                    let frame = try replay.render(highlight: nil)
                    guard let bitmap = MobileBitmapRenderer.image(frame),
                          let image = Self.movieFrame(bitmap, viewport: viewport, renderScale: replay.renderScale) else {
                        throw MobileSessionError.invalidFrame
                    }
                    movieEffects.record(session: replay, viewport: viewport, into: recorder)
                    recorder.append(image)
                    guard recorder.isAcceptingFrames else { break }
                    if replay.snapshot.isComplete || expected.map({ replay.snapshot.tick >= $0 }) == true { break }
                    replay.tick()
                    await Task.yield()
                } while !cancelled.cancelled
                guard !cancelled.cancelled else { return }
                recorder.finish { [weak self] result in
                    guard let self, !cancelled.cancelled else { return }
                    switch result {
                    case let .success(url):
                        #if os(tvOS)
                        MobileTVFileTransfer.exportFile(url, from: self) { [weak self] in
                            try? FileManager.default.removeItem(at: url)
                            self?.returnToResult()
                        }
                        #else
                        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        sheet.popoverPresentationController?.sourceView = self.view
                        sheet.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
                        sheet.completionWithItemsHandler = { [weak self] _, _, _, _ in
                            self?.returnToResult()
                        }
                        self.present(sheet, animated: true)
                        #endif
                    case let .failure(error):
                        self.showCustomOverlay(title: error.localizedDescription, details: [], actions: [
                            ("TRY AGAIN", { [weak self] in self?.shareReplayMovie(document: document) }),
                            ("LIBRARY", { [weak self] in self?.leaveToLibrary() }),
                        ])
                    }
                }
            } catch {
                recorder.discard()
                self.showCustomOverlay(title: error.localizedDescription, details: [], actions: [("LIBRARY", { [weak self] in self?.leaveToLibrary() })])
            }
        }
    }

    private static func movieFrame(_ image: CGImage, viewport: MobileViewport, renderScale: Double) -> CGImage? {
        let visible = viewport.visibleLevelRect
        let source = CGRect(x: visible.x * renderScale, y: visible.y * renderScale, width: visible.width * renderScale, height: visible.height * renderScale)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !source.isEmpty, let crop = image.cropping(to: source) else { return nil }
        let width = 960
        let height = max(2, Int(Double(width) * source.height / source.width / viewport.pixelAspect) / 2 * 2)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

@MainActor private final class MobileReplayExportCancellation {
    var cancelled = false
}
#endif
