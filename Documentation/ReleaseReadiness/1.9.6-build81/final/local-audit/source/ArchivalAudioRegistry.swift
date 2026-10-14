import Foundation

/// Unified registry for all platform soundtracks and sound effect banks across
/// all 16 historical Lemmings releases.
public struct ArchivalAudioRegistry: Sendable {
    public struct SoundTrackItem: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let platformId: String
        public let format: String

        public init(id: String, title: String, platformId: String, format: String) {
            self.id = id
            self.title = title
            self.platformId = platformId
            self.format = format
        }
    }

    public struct SoundBankItem: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let platformId: String
        public let sampleRate: Double

        public init(id: String, name: String, platformId: String, sampleRate: Double) {
            self.id = id
            self.name = name
            self.platformId = platformId
            self.sampleRate = sampleRate
        }
    }

    public static let soundtracks: [SoundTrackItem] = [
        SoundTrackItem(id: "amiga_mod", title: "Amiga CoLD SToRAGE MODs", platformId: "amiga", format: "ProTracker MOD"),
        SoundTrackItem(id: "dos_opl2", title: "DOS AdLib OPL2 FM", platformId: "dos_vga", format: "AdLib FM"),
        SoundTrackItem(id: "snes_spc", title: "SNES Hiroyuki Masuno SPC", platformId: "snes", format: "SPC700 ADPCM"),
        SoundTrackItem(id: "nes_nsf", title: "NES / Famicom NSF", platformId: "nes", format: "RP2A03 APU"),
        SoundTrackItem(id: "genesis_fm", title: "Sega Genesis / Mega Drive FM", platformId: "genesis", format: "YM2612 FM"),
        SoundTrackItem(id: "sms_psg", title: "Master System PSG Chiptunes", platformId: "master_system", format: "SN76489 PSG"),
        SoundTrackItem(id: "gb_papu", title: "Game Boy PAPU Chiptunes", platformId: "game_boy", format: "Game Boy PAPU"),
        SoundTrackItem(id: "c64_sid", title: "Commodore 64 SID Chiptunes", platformId: "c64", format: "MOS 6581 SID"),
        SoundTrackItem(id: "cd_audio", title: "Redbook CD Studio Soundtrack", platformId: "pce_cd", format: "Redbook CD Audio"),
    ]

    public static let soundBanks: [SoundBankItem] = [
        SoundBankItem(id: "amiga_voice", name: "Amiga Digitised Voices (\"Oh No!\", \"Yippee!\")", platformId: "amiga", sampleRate: 22050),
        SoundBankItem(id: "mac_snd", name: "Macintosh Sound Manager SND", platformId: "macintosh", sampleRate: 22050),
        SoundBankItem(id: "dos_sb", name: "DOS Sound Blaster RAW Clips", platformId: "dos_vga", sampleRate: 20833),
        SoundBankItem(id: "snes_fx", name: "Super Nintendo SPC Sound FX", platformId: "snes", sampleRate: 32000),
        SoundBankItem(id: "arcade_fx", name: "Arcade YM2151/OKI Sound FX", platformId: "arcade", sampleRate: 32000),
    ]

    public init() {}
}
