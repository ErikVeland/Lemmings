#if os(iOS) || os(tvOS)
import AVFAudio
import Foundation
import os
import LemmingsMobileCore

/// Blocking audio-session configuration runs on this actor's executor.
private actor MobileAudioSessionWorker {
    static let shared = MobileAudioSessionWorker()
    private let logger = Logger(subsystem: "com.ultimatelemmings.audio", category: "Session")

    func perform(_ operation: MobileAudioSessionOperation) async throws {
        let session = AVAudioSession.sharedInstance()
        do {
        switch operation {
        case .prepare:
            try prepare(session)
        case .resume:
            try prepare(session)
            try session.setActive(true)
            let route = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
            logger.notice("Audio active: rate=\(session.sampleRate, privacy: .public), IO=\(session.ioBufferDuration, privacy: .public), latency=\(session.outputLatency, privacy: .public), route=\(route, privacy: .public)")
        case .suspend:
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        }
        } catch {
            logger.error("Audio session failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    private func prepare(_ session: AVAudioSession) throws {
        #if os(iOS)
        let respectMute = MobileSettings.load(from: .standard).respectMuteSetting
        let category: AVAudioSession.Category = respectMute ? .ambient : .playback
        let options: AVAudioSession.CategoryOptions = respectMute ? [] : [.mixWithOthers]
        #else
        let category: AVAudioSession.Category = .ambient
        let options: AVAudioSession.CategoryOptions = []
        #endif
        if session.category != category || session.mode != .default || session.categoryOptions != options {
            try session.setCategory(category, mode: .default, options: options)
        }
        // The device chooses the actual duration. Log it after activation.
        let preferredDuration = 1024.0 / 44100.0
        if abs(session.preferredIOBufferDuration - preferredDuration) > 0.0001 {
            try session.setPreferredIOBufferDuration(preferredDuration)
        }
    }
}

final class MobileNotificationObserverBag: @unchecked Sendable {
    private var observers: [NSObjectProtocol] = []

    func append(_ observer: NSObjectProtocol) {
        observers.append(observer)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@MainActor final class MobileAudioSessionController {
    enum Event {
        case interruptionBegan
        case interruptionEnded
        case outputRouteLost
    }

    var onEvent: ((Event) -> Void)?
    private let observers = MobileNotificationObserverBag()
    private let requests: MobileAudioSessionRequests

    init() {
        requests = MobileAudioSessionRequests(queue: .shared) {
            try await MobileAudioSessionWorker.shared.perform($0)
        }
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let interruption = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated { self?.handleInterruption(interruption) }
        })
        observers.append(centre.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let routeChange = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.handleRouteChange(routeChange) }
        })
        observers.append(centre.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Invalidate any activation in flight and wait for the player's Resume.
                self?.onEvent?(.interruptionBegan)
                self?.onEvent?(.interruptionEnded)
            }
        })
    }

    static func applySettings() {
        _ = MobileAudioSessionWorkQueue.shared.enqueue({
            try await MobileAudioSessionWorker.shared.perform(.prepare)
        }, completion: { _ in })
    }

    func prepare() {
        requests.prepare()
    }

    func resume(completion: @escaping @MainActor (Bool) -> Void) {
        requests.resume(completion: completion)
    }

    func suspend() {
        requests.suspend()
    }

    private func handleInterruption(_ raw: UInt?) {
        guard let raw,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            onEvent?(.interruptionBegan)
        case .ended:
            // Keep the audio session inactive until the player chooses Resume.
            onEvent?(.interruptionEnded)
        @unknown default:
            onEvent?(.interruptionBegan)
        }
    }

    private func handleRouteChange(_ raw: UInt?) {
        guard let raw,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        onEvent?(.outputRouteLost)
    }
}
#endif
