#if os(iOS)
import AVFAudio
import Foundation

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

    init() {
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
                try? self?.prepare()
                self?.onEvent?(.interruptionEnded)
            }
        })
    }

    func prepare() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
    }

    func resume() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
        try session.setActive(true)
    }

    func suspend() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
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
