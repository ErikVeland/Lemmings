import Foundation
import NxlvKit

/**
 * Supplies presentation pixels without adding an artwork dependency to the session layer.
 */
public protocol ClassicMobileArtworkProvider: AnyObject {
    var revision: String { get }
    var isEnabled: Bool { get }
    var renderScale: Int { get }
    func scene(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation) -> MobilePixelFrame?
    func sprite(_ lemming: ClassicDOSLemming, simulation: ClassicDOSSimulation) -> MobileSpriteHighlight?
    func skill(control: Int) -> MobilePixelFrame?
}

/**
 * Installs the platform's artwork adapter before a prepared session draws its first frame.
 */
public protocol MobileArtworkInstalling: Sendable {
    var revision: String { get }
    func install(on session: any MobileGameSession)
}

public enum MobileArtworkInstallation {
    public static let nativeActorBodies = TaskLocal<Bool>(wrappedValue: true)
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var value: (any MobileArtworkInstalling)?
        func read() -> (any MobileArtworkInstalling)? { lock.lock(); defer { lock.unlock() }; return value }
        func set(_ value: any MobileArtworkInstalling) { lock.lock(); self.value = value; lock.unlock() }
    }
    private static let storage = Storage()
    public static var revision: String { storage.read()?.revision ?? "native" }
    public static func activate(_ installer: any MobileArtworkInstalling) { storage.set(installer) }
    public static func install(on session: any MobileGameSession) { storage.read()?.install(on: session) }
}
