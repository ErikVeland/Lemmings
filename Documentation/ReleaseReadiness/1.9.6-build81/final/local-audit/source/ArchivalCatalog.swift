import Foundation

/// Central archival registry cataloging all 16 historical ports of Lemmings,
/// their hardware specs, exclusive levels, soundtracks, sound effect banks,
/// graphics chipsets, and historical preservation notes.
public struct ArchivalCatalog: Sendable {
    public struct PlatformInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let releaseYear: Int
        public let developer: String
        public let audioHardware: String
        public let displayChipset: String
        public let exclusiveLevelCount: Int
        public let notes: String

        public init(
            id: String,
            name: String,
            releaseYear: Int,
            developer: String,
            audioHardware: String,
            displayChipset: String,
            exclusiveLevelCount: Int,
            notes: String
        ) {
            self.id = id
            self.name = name
            self.releaseYear = releaseYear
            self.developer = developer
            self.audioHardware = audioHardware
            self.displayChipset = displayChipset
            self.exclusiveLevelCount = exclusiveLevelCount
            self.notes = notes
        }
    }

    /// Complete registry of all 16 historical Lemmings ports.
    public static let platforms: [PlatformInfo] = [
        PlatformInfo(
            id: "amiga",
            name: "Commodore Amiga 500 / 1000 / 2000",
            releaseYear: 1991,
            developer: "DMA Design",
            audioHardware: "Paula 8364 4-Channel 8-Bit PCM / MOD",
            displayChipset: "OCS / ECS 32-Color 3-Plane / 4-Plane",
            exclusiveLevelCount: 20,
            notes: "Original lead platform. Includes iconic digitised voice samples and 2-Player split-screen."
        ),
        PlatformInfo(
            id: "dos_vga",
            name: "PC Compatible (DOS VGA)",
            releaseYear: 1991,
            developer: "DMA Design / Psygnosis",
            audioHardware: "OPL2 YM3812 / Sound Blaster / Tandy",
            displayChipset: "VGA 320x200 256-Color (VGASPEC)",
            exclusiveLevelCount: 0,
            notes: "Canonical 17 Hz logic tick accumulator engine. Standard DOS campaign of 120 levels."
        ),
        PlatformInfo(
            id: "dos_ega",
            name: "PC Compatible (DOS EGA / CGA)",
            releaseYear: 1991,
            developer: "DMA Design / Psygnosis",
            audioHardware: "PC Speaker / AdLib FM",
            displayChipset: "EGA 16-Color / CGA 4-Color",
            exclusiveLevelCount: 0,
            notes: "Retro 16-color and 4-color paletted modes."
        ),
        PlatformInfo(
            id: "macintosh",
            name: "Apple Macintosh (Classic Mac OS)",
            releaseYear: 1992,
            developer: "Presage Software / Psygnosis",
            audioHardware: "Macintosh Sound Manager 22 kHz PCM",
            displayChipset: "Mac 2× High-Resolution (512x342 / 640x480)",
            exclusiveLevelCount: 0,
            notes: "Crisp retina-class 2× graphics, high-res fonts, Mac UI panel, and festive Xmas sprites."
        ),
        PlatformInfo(
            id: "snes",
            name: "Super Nintendo Entertainment System (SNES)",
            releaseYear: 1992,
            developer: "Sunsoft / DMA Design",
            audioHardware: "Sony SPC700 16-Bit ADPCM Synth",
            displayChipset: "SNES Mode 2 / Mode 7 Special",
            exclusiveLevelCount: 5,
            notes: "Features 5 exclusive Sunsoft Special levels and custom Hiroyuki Masuno SPC soundtrack."
        ),
        PlatformInfo(
            id: "genesis",
            name: "Sega Genesis / Mega Drive",
            releaseYear: 1992,
            developer: "Sunsoft / Probe Software",
            audioHardware: "Yamaha YM2612 6-Channel FM",
            displayChipset: "Sega VDP 64-Color 320x224",
            exclusiveLevelCount: 60,
            notes: "Features 60 exclusive levels (Presenter rating 1–30 + bonus levels) and Matt Furniss FM tracks."
        ),
        PlatformInfo(
            id: "arcade",
            name: "Arcade (Data East / Sega Arcade)",
            releaseYear: 1992,
            developer: "Data East / Sega",
            audioHardware: "Yamaha YM2151 FM + OKI ADPCM Voice",
            displayChipset: "Arcade RGB Video Board 320x240",
            exclusiveLevelCount: 10,
            notes: "Features arcade single-player stages, 2-Player Co-Op mode, countdown timers, and high-score screens."
        ),
        PlatformInfo(
            id: "atari_st",
            name: "Atari ST / STE",
            releaseYear: 1991,
            developer: "DMA Design",
            audioHardware: "Yamaha YM2149 3-Voice SSG",
            displayChipset: "Atari ST 16-Color Palette",
            exclusiveLevelCount: 0,
            notes: "Custom Atari ST chiptune music arrangements by Tim Wright."
        ),
        PlatformInfo(
            id: "archimedes",
            name: "Acorn Archimedes",
            releaseYear: 1992,
            developer: "Krisalis Software",
            audioHardware: "VIDC1 8-Channel 8-Bit Stereo Direct Sound",
            displayChipset: "ARM VIDC 256-Color 50 Hz",
            exclusiveLevelCount: 4,
            notes: "32-bit ARM RISC native build featuring 4 Archimedes-exclusive levels."
        ),
        PlatformInfo(
            id: "master_system",
            name: "Sega Master System / Game Gear",
            releaseYear: 1992,
            developer: "Probe Software",
            audioHardware: "SN76489 4-Channel PSG",
            displayChipset: "VDP 32-Color 256x192 / 160x144",
            exclusiveLevelCount: 0,
            notes: "8-bit chiptune soundtrack by Matt Furniss and compact handheld level variations."
        ),
        PlatformInfo(
            id: "game_boy",
            name: "Nintendo Game Boy / Game Boy Color",
            releaseYear: 1992,
            developer: "Ocean Software",
            audioHardware: "Game Boy PAPU 4-Channel Audio",
            displayChipset: "Monochrome 4-Shade LCD 160x144",
            exclusiveLevelCount: 0,
            notes: "Tailored compact handheld level maps and chiptune audio."
        ),
        PlatformInfo(
            id: "c64",
            name: "Commodore 64",
            releaseYear: 1993,
            developer: "Alligator / Psygnosis",
            audioHardware: "MOS 6581 / 8580 SID 3-Voice Synth",
            displayChipset: "VIC-II 16-Color Multicolor 160x200",
            exclusiveLevelCount: 0,
            notes: "Classic C64 SID chiptune music and VIC-II sprite graphics."
        ),
        PlatformInfo(
            id: "spectrum",
            name: "ZX Spectrum / Amstrad CPC",
            releaseYear: 1992,
            developer: "Target Software",
            audioHardware: "AY-3-8912 3-Channel Chiptune",
            displayChipset: "Spectrum 8-Color / CPC Mode 0 16-Color",
            exclusiveLevelCount: 0,
            notes: "8-bit microcomputer port with authentic AY sound."
        ),
        PlatformInfo(
            id: "pce_cd",
            name: "PC Engine CD / TurboGrafx-CD",
            releaseYear: 1992,
            developer: "Hudson Soft / Sunsoft",
            audioHardware: "Redbook CD-Audio + HuC6280 PSG",
            displayChipset: "HuC6270 512-Color Video",
            exclusiveLevelCount: 0,
            notes: "Full studio CD-Audio arranged soundtrack and animated intro sequences."
        ),
        PlatformInfo(
            id: "threedo_ps1",
            name: "3DO Interactive Multiplayer / PlayStation",
            releaseYear: 1994,
            developer: "Psygnosis",
            audioHardware: "Redbook CD-Audio 44.1 kHz Stereo",
            displayChipset: "32-Bit Framebuffer High-Res",
            exclusiveLevelCount: 0,
            notes: "High-fidelity CD Audio and FMV cinematic cutscenes."
        ),
        PlatformInfo(
            id: "neolemmix",
            name: "NeoLemmix Community Engine",
            releaseYear: 2014,
            developer: "NeoLemmix Community",
            audioHardware: "Digital Sound Bank (WAV/FLAC)",
            displayChipset: "Vector/Raster Style Packs",
            exclusiveLevelCount: 1000,
            notes: "Modern open level format (.nxlv) and custom style pack support."
        ),
    ]

    public init() {}

    public static func platform(for id: String) -> PlatformInfo? {
        platforms.first { $0.id == id }
    }
}
