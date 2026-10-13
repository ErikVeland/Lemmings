#if os(iOS)
import AVFAudio
import Foundation

/// Blocking audio-session configuration runs on this actor's executor.
private actor MobileAudioSessionWorker {
    static let shared = MobileAudioSessionWorker()

    func perform(_ operation: MobileAudioSessionOperation) async throws {
        let session = AVAudioSession.sharedInstance()
        switch operation {
        case .prepare:
            try prepare(session)
        case .resume:
            try prepare(session)
            try session.setActive(true)
        case .suspend:
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func prepare(_ session: AVAudioSession) throws {
        try session.setCategory(.ambient, mode: .default, options: [])
        // Give tracker synthesis and effects one 1,024-frame buffer at 44.1 kHz.
        try session.setPreferredIOBufferDuration(1024.0 / 44100.0)
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
