#if os(iOS) || os(tvOS)
import AVFAudio
import Foundation
import LemmingsAudio

/// A short audio lifecycle record in Caches for device reports. Logs from an attached device need
/// root, but `devicectl` can copy this file from the app container. Render threads never write to it.
enum MobileAudioEventLog {
    static let fileName = "AudioEvents.log"
    private static let limit = 128 * 1024
    private static let queue = DispatchQueue(label: "Lemmings.audio-event-log", qos: .utility)
    private static let enabled = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted"
    private static let observers: MobileNotificationObserverBag = {
        let observers = MobileNotificationObserverBag()
        let centre = NotificationCenter.default
        // Observers without a queue run on the posting thread, so the main actor never reads the session.
        observers.append(centre.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            record("route change reason=\(reason.map(String.init) ?? "nil")", session: true)
        })
        observers.append(centre.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { notification in
            let engine = notification.object.map { "\(Unmanaged.passUnretained($0 as AnyObject).toOpaque())" } ?? "nil"
            record("engine configuration change engine=\(engine)", session: true)
        })
        observers.append(centre.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            record("interruption type=\(type.map(String.init) ?? "nil")", session: true)
        })
        observers.append(centre.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { _ in
            record("media services reset", session: true)
        })
        return observers
    }()

    static func start() {
        guard enabled else { return }
        _ = observers
        record("launch", session: true)
    }

    /// `session` adds the negotiated rate, I/O duration, latency and output route.
    static func record(_ event: @autoclosure () -> String, session: Bool = false) {
        guard enabled else { return }
        let event = event()
        let stamp = String(format: "%.3f %.3f", Date().timeIntervalSince1970, ProcessInfo.processInfo.systemUptime)
        queue.async {
            append("\(stamp) \(event)\(session ? " " + sessionState() : "")\n")
        }
    }

    static func summary(_ statistics: [AudioBufferStatistics]) -> String {
        statistics.map {
            "[starts=\($0.starts) refills=\($0.refills) failed=\($0.refillFailures) slow=\($0.refillsOverReserve) "
                + String(format: "maxRefill=%.4f maxWait=%.4f ", $0.maximumRefillSeconds, $0.maximumQueueWaitSeconds)
                + "lateWaits=\($0.queueWaitsOverReserve) empty=\($0.emptyReserveObservations) "
                + "minReserve=\($0.minimumReserveFrames.map(String.init) ?? "nil")]"
        }.joined(separator: " ")
    }

    private static func sessionState() -> String {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute.outputs.map { "\($0.portType.rawValue)x\($0.channels?.count ?? 0)" }.joined(separator: ",")
        return String(format: "rate=%.0f io=%.5f latency=%.5f ", session.sampleRate, session.ioBufferDuration, session.outputLatency)
            + "channels=\(session.outputNumberOfChannels) route=\(route.isEmpty ? "none" : route)"
    }

    private static func append(_ line: String) {
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let url = directory.appendingPathComponent(fileName)
        var contents = (try? Data(contentsOf: url)) ?? Data()
        contents.append(Data(line.utf8))
        // Keep the newest half when the record reaches its limit.
        if contents.count > limit, let newline = contents.dropFirst(contents.count - limit / 2).firstIndex(of: 0x0A) {
            contents = contents[(newline + 1)...]
        }
        try? contents.write(to: url, options: .atomic)
    }
}
#endif
