import Foundation

/// What the player has chosen, and what they are allowed to choose.
///
/// A platform profile bundles a machine's look and sound together, which is
/// the right default. This lets those choices come apart, so Amiga music can
/// play over DOS graphics, or a modern remix over either.
///
/// Options are derived from what is installed rather than listed by the
/// interface. An interface that lists every source will offer Macintosh music
/// to someone who has no Macintosh disk, and then fail when they pick it.

/// Where the level and sprite artwork comes from.
public enum ClassicGraphicsSource: Equatable, Codable, Sendable {
    case dosVGA
    case amiga
    case macintosh
    /// A folder of replacement artwork the player supplied.
    case custom(name: String)

    public var displayName: String {
        switch self {
        case .dosVGA: return "DOS (VGA)"
        case .amiga: return "Amiga"
        case .macintosh: return "Macintosh"
        case let .custom(name): return name
        }
    }
}

/// Where the music comes from.
public enum ClassicMusicSource: Equatable, Codable, Sendable {
    case adaptiveDJ
    case amigaModules
    case macintoshMIDI
    case dosAdlib
    case snesSPC
    case genesisFM
    case cdAudio
    /// A folder of remixed or re-recorded tracks the player supplied.
    case remix(name: String)
    case silent

    public var displayName: String {
        switch self {
        case .adaptiveDJ: return "Adaptive DJ Mix (The True Choice) 🎧"
        case .amigaModules: return "Amiga Modules"
        case .macintoshMIDI: return "Macintosh MIDI"
        case .dosAdlib: return "DOS Ad-Lib (OPL2)"
        case .snesSPC: return "SNES SPC Synth"
        case .genesisFM: return "Sega Genesis FM"
        case .cdAudio: return "CD Audio Stream"
        case let .remix(name): return name
        case .silent: return "None"
        }
    }
}

/// Where the sound effects come from.
public enum ClassicSoundSource: Equatable, Codable, Sendable {
    case macintoshResources
    case amigaVoices
    case dosAdlib
    case sampleBank
    case snes
    case arcade
    case silent

    public var displayName: String {
        switch self {
        case .macintoshResources: return "Macintosh"
        case .amigaVoices: return "Amiga Voices"
        case .dosAdlib: return "DOS Ad-Lib"
        case .sampleBank: return "Sample Bank"
        case .snes: return "Super Nintendo"
        case .arcade: return "Arcade"
        case .silent: return "None"
        }
    }
}

/// How the picture is presented.
public enum ClassicDisplayMode: String, Equatable, Codable, CaseIterable, Sendable {
    /// No tube simulation. Sharp pixels on a flat panel.
    case flat
    /// A monitor of the period, as most people saw an Amiga.
    case monitor
    /// A television over composite, which is softer and bloomier.
    case television

    public var displayName: String {
        switch self {
        case .flat: return "Flat Panel"
        case .monitor: return "Monitor"
        case .television: return "Television"
        }
    }
}

/// Colour depth of the output.
public enum ClassicColorDepth: String, Equatable, Codable, CaseIterable, Sendable {
    /// Whatever the artwork already holds.
    case full
    /// Four bits per channel, as an Amiga OCS or ECS chipset showed.
    case amigaOCS

    public var displayName: String {
        switch self {
        case .full: return "Full"
        case .amigaOCS: return "Amiga (4 bit)"
        }
    }

    /// Levels per channel, or zero to leave the artwork alone.
    public var levels: Int {
        switch self {
        case .full: return 0
        case .amigaOCS: return 16
        }
    }
}

/// How music is treated on the way out.
public enum ClassicMusicStyle: String, Equatable, Codable, CaseIterable, Sendable {
    /// Exactly as the hardware played it.
    case faithful
    /// Widened, equalised and given a small room.
    case modern

    public var displayName: String {
        switch self {
        case .faithful: return "Faithful"
        case .modern: return "Modern"
        }
    }
}

public struct ClassicSettings: Equatable, Codable, Sendable {
    // Graphics
    public var graphics: ClassicGraphicsSource
    public var colorDepth: ClassicColorDepth

    // Video
    public var display: ClassicDisplayMode
    /// Strength of the tube simulation, from 0 to 1.
    public var displayIntensity: Double
    /// Horizontal stretch. PAL pixels are not square.
    public var pixelAspect: Double
    public var integerScaling: Bool
    public var modernControlsEnabled: Bool
    public var variableSpeedEnabled: Bool
    public var pauseOnInterruption: Bool
    public var controllerEnabled: Bool
    public var controllerTapSpeed: Bool
    public var controllerMappings: [String: String]
    public var controllerSwapSticks: Bool
    public var reduceMotion: Bool
    public var reduceFlashes: Bool
    public var speedEffectsEnabled: Bool { hdEffectsEnabled && !reduceMotion }
    public var explosionEffectsEnabled: Bool { hdEffectsEnabled && !reduceFlashes }
    public var cinematicExplosionsEnabled: Bool { explosionEffectsEnabled && !reduceMotion && fullScreenHDRFlashes }
    public var hdEffectsEnabled: Bool
    public var confinePointer: Bool
    public var fullScreenHDRFlashes: Bool
    public var djIncludesOtherSoundtracks: Bool

    // Audio
    public var music: ClassicMusicSource
    public var musicStyle: ClassicMusicStyle
    public var musicVolume: Double
    public var sound: ClassicSoundSource
    public var soundVolume: Double

    /// Picks a different artwork source for each level.
    ///
    /// Most people met this game on one machine. Shuffling means a run passes
    /// through all of them, which is the point of holding every release at
    /// once rather than picking one and staying there.
    public var shuffleGraphics: Bool
    /// Picks a different soundtrack for each level, on the same reasoning.
    public var shuffleMusic: Bool

    public init(
        graphics: ClassicGraphicsSource = .macintosh,
        colorDepth: ClassicColorDepth = .full,
        display: ClassicDisplayMode = .flat,
        displayIntensity: Double = 0.8,
        pixelAspect: Double = 1.0,
        integerScaling: Bool = true,
        modernControlsEnabled: Bool = true,
        variableSpeedEnabled: Bool = true,
        pauseOnInterruption: Bool = true,
        controllerEnabled: Bool = true,
        controllerTapSpeed: Bool = true,
        controllerSwapSticks: Bool = false,
        controllerMappings: [String: String] = [:],
        reduceMotion: Bool = false,
        reduceFlashes: Bool = false,
        hdEffectsEnabled: Bool = true,
        confinePointer: Bool = true,
        fullScreenHDRFlashes: Bool = true,
        djIncludesOtherSoundtracks: Bool = true,
        music: ClassicMusicSource = .amigaModules,
        musicStyle: ClassicMusicStyle = .faithful,
        musicVolume: Double = 0.8,
        sound: ClassicSoundSource = .macintoshResources,
        soundVolume: Double = 0.9,
        shuffleGraphics: Bool = false,
        shuffleMusic: Bool = false
    ) {
        self.graphics = graphics
        self.colorDepth = colorDepth
        self.display = display
        self.displayIntensity = displayIntensity
        self.pixelAspect = pixelAspect
        self.integerScaling = integerScaling
        self.modernControlsEnabled = modernControlsEnabled
        self.variableSpeedEnabled = variableSpeedEnabled
        self.pauseOnInterruption = pauseOnInterruption
        self.controllerEnabled = controllerEnabled
        self.controllerTapSpeed = controllerTapSpeed
        self.controllerSwapSticks = controllerSwapSticks
        self.controllerMappings = ControllerBindings.validatedMapping(controllerMappings)
        self.reduceMotion = reduceMotion
        self.reduceFlashes = reduceFlashes
        self.hdEffectsEnabled = hdEffectsEnabled
        self.confinePointer = confinePointer
        self.fullScreenHDRFlashes = fullScreenHDRFlashes
        self.djIncludesOtherSoundtracks = djIncludesOtherSoundtracks
        self.music = music
        self.musicStyle = musicStyle
        self.musicVolume = musicVolume
        self.sound = sound
        self.soundVolume = soundVolume
        self.shuffleGraphics = shuffleGraphics
        self.shuffleMusic = shuffleMusic
    }

    /// Reads settings written by an older build.
    ///
    /// Swift's generated decoder rejects a file that is missing any key, so a
    /// new setting would throw away everything the player had chosen. Each
    /// field falls back to its default instead.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ClassicSettings()

        /// Reads one source, and falls back when the stored case is gone.
        ///
        /// A missing key means an older build that did not write the setting.
        /// A key that fails to decode means a build that wrote a source this
        /// one has removed, such as the DOS EGA artwork that never shipped.
        /// Both cases fall back to the default rather than throwing, because a
        /// throw here discards every other choice the player made.
        func source<T: Decodable>(_ key: CodingKeys, _ fallbackValue: T) -> T {
            // `try?` flattens the optional the decoder returns, so a missing
            // key and a case that will not decode both arrive here as nil.
            guard let decoded = try? values.decodeIfPresent(T.self, forKey: key) else {
                return fallbackValue
            }
            return decoded
        }

        graphics = source(.graphics, fallback.graphics)
        colorDepth = try values.decodeIfPresent(
            ClassicColorDepth.self, forKey: .colorDepth) ?? fallback.colorDepth
        display = try values.decodeIfPresent(
            ClassicDisplayMode.self, forKey: .display) ?? fallback.display
        displayIntensity = try values.decodeIfPresent(
            Double.self, forKey: .displayIntensity) ?? fallback.displayIntensity
        pixelAspect = try values.decodeIfPresent(
            Double.self, forKey: .pixelAspect) ?? fallback.pixelAspect
        integerScaling = try values.decodeIfPresent(
            Bool.self, forKey: .integerScaling) ?? fallback.integerScaling
        modernControlsEnabled = try values.decodeIfPresent(Bool.self, forKey: .modernControlsEnabled) ?? fallback.modernControlsEnabled
        variableSpeedEnabled = try values.decodeIfPresent(Bool.self, forKey: .variableSpeedEnabled) ?? fallback.variableSpeedEnabled
        pauseOnInterruption = try values.decodeIfPresent(Bool.self, forKey: .pauseOnInterruption) ?? modernControlsEnabled
        controllerEnabled = try values.decodeIfPresent(Bool.self, forKey: .controllerEnabled) ?? modernControlsEnabled
        controllerTapSpeed = try values.decodeIfPresent(Bool.self, forKey: .controllerTapSpeed) ?? fallback.controllerTapSpeed
        controllerSwapSticks = try values.decodeIfPresent(Bool.self, forKey: .controllerSwapSticks) ?? fallback.controllerSwapSticks
        controllerMappings = ControllerBindings.validatedMapping((try? values.decodeIfPresent([String: String].self, forKey: .controllerMappings)) ?? [:])
        reduceMotion = try values.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        reduceFlashes = try values.decodeIfPresent(Bool.self, forKey: .reduceFlashes) ?? false
        hdEffectsEnabled = try values.decodeIfPresent(Bool.self, forKey: .hdEffectsEnabled) ?? fallback.hdEffectsEnabled
        confinePointer = try values.decodeIfPresent(Bool.self, forKey: .confinePointer) ?? fallback.confinePointer
        fullScreenHDRFlashes = try values.decodeIfPresent(Bool.self, forKey: .fullScreenHDRFlashes) ?? fallback.fullScreenHDRFlashes
        djIncludesOtherSoundtracks = try values.decodeIfPresent(Bool.self, forKey: .djIncludesOtherSoundtracks) ?? fallback.djIncludesOtherSoundtracks
        music = source(.music, fallback.music)
        musicStyle = try values.decodeIfPresent(
            ClassicMusicStyle.self, forKey: .musicStyle) ?? fallback.musicStyle
        musicVolume = try values.decodeIfPresent(
            Double.self, forKey: .musicVolume) ?? fallback.musicVolume
        sound = source(.sound, fallback.sound)
        soundVolume = try values.decodeIfPresent(
            Double.self, forKey: .soundVolume) ?? fallback.soundVolume
        shuffleGraphics = try values.decodeIfPresent(
            Bool.self, forKey: .shuffleGraphics) ?? fallback.shuffleGraphics
        shuffleMusic = try values.decodeIfPresent(
            Bool.self, forKey: .shuffleMusic) ?? fallback.shuffleMusic
    }

    /// Changes the added conveniences while preserving the chosen machine and volumes.
    public mutating func applyExperiencePreset(modern: Bool) {
        modernControlsEnabled = modern
        variableSpeedEnabled = modern
        pauseOnInterruption = modern
        controllerEnabled = modern
        controllerTapSpeed = modern
        controllerSwapSticks = false
        controllerMappings = [:]
        hdEffectsEnabled = modern
        fullScreenHDRFlashes = modern
        confinePointer = modern
        djIncludesOtherSoundtracks = modern
        shuffleGraphics = false
        shuffleMusic = false
        musicStyle = .faithful
        if !modern, music == .adaptiveDJ { music = .amigaModules }
    }

    /// Settings that match a machine, as a starting point before mixing.
    public static func matching(_ profile: PlatformProfile) -> ClassicSettings {
        var settings = ClassicSettings()
        settings.colorDepth = profile.colorLevels == 16 ? .amigaOCS : .full
        settings.pixelAspect = profile.pixelAspect
        switch profile.display {
        case .rgbMonitor: settings.display = .monitor
        case .television: settings.display = .television
        case .flatPanel: settings.display = .flat
        }
        switch profile.music {
        case .protrackerModule: settings.music = .amigaModules
        case .midiWithSamples: settings.music = .macintoshMIDI
        case .adlibFM: settings.music = .dosAdlib
        case .none: settings.music = .silent
        }
        switch profile.sound {
        case .macResourceSounds: settings.sound = .macintoshResources
        case .adlibFM: settings.sound = .dosAdlib
        case .sampleBank: settings.sound = .sampleBank
        case .none: settings.sound = .silent
        }
        switch profile.identifier {
        case "amiga": settings.graphics = .amiga
        case "macintosh": settings.graphics = .macintosh
        default: settings.graphics = .dosVGA
        }
        return settings
    }
}

/// What can actually be chosen, given the data present.
public struct ClassicSettingsOptions: Sendable {
    public let graphics: [ClassicGraphicsSource]
    public let music: [ClassicMusicSource]
    public let sound: [ClassicSoundSource]

    public init(
        graphics: [ClassicGraphicsSource],
        music: [ClassicMusicSource],
        sound: [ClassicSoundSource]
    ) {
        self.graphics = graphics
        self.music = music
        self.sound = sound
    }

    /// Sources with a decoder behind them today.
    ///
    /// A source stays out of the offered list until something can play it. A
    /// control that changes nothing is worse than a control that is missing,
    /// because the player cannot tell which of their choices took effect.
    /// Adding a decoder means adding its source here.
    public static let playableMusic: [ClassicMusicSource] = [.amigaModules, .adaptiveDJ, .silent]
    public static let playableSound: [ClassicSoundSource] = [
        .macintoshResources, .amigaVoices, .silent,
    ]

    /// What the installed data supports.
    ///
    /// Sources that are not decoded yet are left out rather than listed and
    /// then failing when chosen. DOS music is the current example: the
    /// synthesizer exists but its sequencer is not decoded.
    public static func available(
        hasDOSData: Bool,
        hasAmigaDisk: Bool,
        hasMacintoshDisk: Bool,
        moduleCount: Int,
        remixFolders: [String] = [],
        customGraphics: [String] = [],
        hasSoundtracks: Bool = false
    ) -> ClassicSettingsOptions {
        var graphics: [ClassicGraphicsSource] = []
        if hasMacintoshDisk { graphics.append(.macintosh) }
        if hasAmigaDisk { graphics.append(.amiga) }
        if hasDOSData { graphics.append(.dosVGA) }
        graphics.append(contentsOf: customGraphics.map { .custom(name: $0) })

        // Only sources with both a decoder and installed data are offered.
        // `playableMusic` and `playableSound` name the decoders that exist;
        // the conditions below name the data that is present.
        var music: [ClassicMusicSource] = []
        if moduleCount > 0 { music.append(.amigaModules) }
        if hasMacintoshDisk { music.append(.macintoshMIDI) }
        // The mix moves between the soundtracks the player supplied, so it
        // needs at least one of them to have anything to play.
        if hasSoundtracks { music.append(.adaptiveDJ) }
        music = music.filter { playableMusic.contains($0) }
        // A soundtrack the player supplied always plays, whatever the machine.
        music.append(contentsOf: remixFolders.map { .remix(name: $0) })
        music.append(.silent)

        var sound: [ClassicSoundSource] = []
        if hasMacintoshDisk { sound.append(.macintoshResources) }
        // The Amiga banks ship with the artwork, so the same flag covers both.
        if hasAmigaDisk { sound.append(.amigaVoices) }
        sound = sound.filter { playableSound.contains($0) }
        sound.append(.silent)

        return ClassicSettingsOptions(graphics: graphics, music: music, sound: sound)
    }

    public func allows(_ settings: ClassicSettings) -> Bool {
        graphics.contains(settings.graphics)
            && music.contains(settings.music)
            && sound.contains(settings.sound)
    }

    /// Moves any unavailable choice to something that works.
    ///
    /// Data can disappear between runs when a folder is moved, so a stored
    /// setting is corrected rather than left pointing at nothing.
    public func correcting(_ settings: ClassicSettings) -> ClassicSettings {
        var corrected = settings
        if !graphics.contains(settings.graphics), let first = graphics.first {
            corrected.graphics = first
        }
        if !music.contains(settings.music) {
            corrected.music = music.first ?? .silent
        }
        if !sound.contains(settings.sound) {
            corrected.sound = sound.first ?? .silent
        }
        return corrected
    }
}
