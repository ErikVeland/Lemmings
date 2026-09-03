import Foundation

/// How the game looked and sounded on one machine.
///
/// Lemmings shipped on many platforms and each sounded and looked different.
/// A profile groups those differences so a player can pick a machine rather
/// than a dozen separate settings.
///
/// A profile only describes intent. Whether it can actually be delivered
/// depends on the data present, which `availability` reports rather than
/// guesses at. A preset that silently falls back to another machine's audio
/// would be worse than one that says what it needs.

public enum MusicFormat: String, Codable, Sendable {
    case protrackerModule
    case midiWithSamples
    case adlibFM
    case none

    public var label: String {
        switch self {
        case .protrackerModule: return "ProTracker modules"
        case .midiWithSamples: return "MIDI with sampled instruments"
        case .adlibFM: return "Ad-Lib FM"
        case .none: return "silent"
        }
    }
}

public enum SoundFormat: String, Codable, Sendable {
    case macResourceSounds
    case sampleBank
    case adlibFM
    case none

    public var label: String {
        switch self {
        case .macResourceSounds: return "Macintosh sound resources"
        case .sampleBank: return "sample bank"
        case .adlibFM: return "Ad-Lib FM"
        case .none: return "silent"
        }
    }
}

/// The kind of screen the machine was normally attached to.
public enum DisplayKind: String, Codable, Sendable {
    case rgbMonitor
    case television
    case flatPanel
}

public struct PlatformProfile: Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    /// Levels per colour channel. 16 is Amiga OCS, 64 is the VGA DAC, and 0
    /// leaves the art untouched.
    public let colorLevels: Int
    /// Horizontal stretch. PAL pixels are not square.
    public let pixelAspect: Double
    public let display: DisplayKind
    public let music: MusicFormat
    public let sound: SoundFormat
    /// Logic ticks per second.
    public let tickRate: Int
    /// What a player has to supply for this profile to be genuine.
    public let requires: [String]

    public init(
        identifier: String, name: String, colorLevels: Int, pixelAspect: Double,
        display: DisplayKind, music: MusicFormat, sound: SoundFormat,
        tickRate: Int, requires: [String]
    ) {
        self.identifier = identifier
        self.name = name
        self.colorLevels = colorLevels
        self.pixelAspect = pixelAspect
        self.display = display
        self.music = music
        self.sound = sound
        self.tickRate = tickRate
        self.requires = requires
    }

    /// A Commodore Amiga on an RGB monitor, which is how most people saw it.
    ///
    /// Four bits per channel, PAL pixels slightly wide, module music.
    public static let amiga = PlatformProfile(
        identifier: "amiga",
        name: "Amiga",
        colorLevels: 16,
        pixelAspect: 1.07,
        display: .rgbMonitor,
        music: .protrackerModule,
        sound: .macResourceSounds,
        tickRate: 17,
        requires: ["Amiga module files", "a sound source"])

    /// A PC with VGA, on the DOS release the engine already runs.
    public static let dosVGA = PlatformProfile(
        identifier: "dos-vga",
        name: "DOS (VGA)",
        colorLevels: 64,
        pixelAspect: 1.2,
        display: .rgbMonitor,
        music: .adlibFM,
        sound: .adlibFM,
        tickRate: 17,
        requires: ["a DOS data directory", "ADLIB.DAT"])

    /// A Macintosh, which drove a sharp monitor and used MIDI for music.
    public static let macintosh = PlatformProfile(
        identifier: "macintosh",
        name: "Macintosh",
        colorLevels: 0,
        pixelAspect: 1.0,
        display: .rgbMonitor,
        music: .midiWithSamples,
        sound: .macResourceSounds,
        tickRate: 17,
        requires: ["a Macintosh disk image"])

    /// Not a machine that existed. The best available part of each.
    ///
    /// Full colour, square pixels, module music, and the Macintosh sound
    /// effects, which are the only ones that record their own rates.
    public static let modern = PlatformProfile(
        identifier: "modern",
        name: "Modern",
        colorLevels: 0,
        pixelAspect: 1.0,
        display: .flatPanel,
        music: .protrackerModule,
        sound: .macResourceSounds,
        tickRate: 17,
        requires: ["Amiga module files", "a Macintosh disk image"])

    public static let all: [PlatformProfile] = [.amiga, .dosVGA, .macintosh, .modern]
}

/// What a profile can actually deliver from the data present.
public struct PlatformAvailability: Sendable {
    public let profile: PlatformProfile
    public let hasLevels: Bool
    public let hasMusic: Bool
    public let hasSound: Bool

    /// True when every part of the profile can be delivered.
    public var isComplete: Bool { hasLevels && hasMusic && hasSound }

    public var missing: [String] {
        var gaps: [String] = []
        if !hasLevels { gaps.append("levels") }
        if !hasMusic { gaps.append("music") }
        if !hasSound { gaps.append("sound") }
        return gaps
    }
}

public enum PlatformLibrary {
    /// Reports what each profile can deliver from the directories given.
    ///
    /// Presence is checked rather than assumed, so a profile is never offered
    /// as authentic when part of it would silently come from elsewhere.
    public static func availability(
        profile: PlatformProfile,
        levelDirectory: URL?,
        moduleDirectory: URL?,
        macImage: URL?
    ) -> PlatformAvailability {
        let manager = FileManager.default

        var hasLevels = false
        if let levelDirectory,
            let contents = try? manager.contentsOfDirectory(
                at: levelDirectory, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) {
            hasLevels = contents.contains { url in
                let name = url.lastPathComponent.lowercased()
                return name.hasSuffix(".dat") && (name.contains("level") || name.contains("dlvel"))
            }
        }

        var hasModules = false
        if let moduleDirectory,
            let walker = manager.enumerator(
                at: moduleDirectory, includingPropertiesForKeys: nil) {
            hasModules = walker.compactMap { $0 as? URL }
                .contains { $0.pathExtension.lowercased() == "mod" }
        }

        var hasMacImage = false
        if let macImage, manager.fileExists(atPath: macImage.path) {
            hasMacImage = (try? Data(contentsOf: macImage, options: .mappedIfSafe))
                .map { (try? ClassicHFSVolume(image: $0)) != nil } ?? false
        }

        let hasMusic: Bool
        switch profile.music {
        case .protrackerModule: hasMusic = hasModules
        case .midiWithSamples: hasMusic = hasMacImage
        case .adlibFM: hasMusic = false  // the sequencer is not decoded yet
        case .none: hasMusic = true
        }

        let hasSound: Bool
        switch profile.sound {
        case .macResourceSounds: hasSound = hasMacImage
        case .sampleBank: hasSound = false
        case .adlibFM: hasSound = false  // same undecoded sequencer
        case .none: hasSound = true
        }

        return PlatformAvailability(
            profile: profile, hasLevels: hasLevels, hasMusic: hasMusic, hasSound: hasSound)
    }
}
