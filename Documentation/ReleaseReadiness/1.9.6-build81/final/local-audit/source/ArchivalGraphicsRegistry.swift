import Foundation

/// Unified registry mapping graphics chipsets, color depth filters, tile renderers,
/// and UI frames across all 16 historical Lemmings ports.
public struct ArchivalGraphicsRegistry: Sendable {
    public struct GraphicsModeItem: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let platformId: String
        public let colorDepthBits: Int
        public let scaleFactor: Double

        public init(id: String, name: String, platformId: String, colorDepthBits: Int, scaleFactor: Double) {
            self.id = id
            self.name = name
            self.platformId = platformId
            self.colorDepthBits = colorDepthBits
            self.scaleFactor = scaleFactor
        }
    }

    public static let graphicsModes: [GraphicsModeItem] = [
        GraphicsModeItem(id: "mac_2x", name: "Macintosh 2× High-Resolution", platformId: "macintosh", colorDepthBits: 8, scaleFactor: 2.0),
        GraphicsModeItem(id: "amiga_ocs", name: "Amiga OCS 32-Color (3-Plane)", platformId: "amiga", colorDepthBits: 4, scaleFactor: 2.0),
        GraphicsModeItem(id: "dos_vga", name: "DOS VGA 256-Color (VGASPEC)", platformId: "dos_vga", colorDepthBits: 8, scaleFactor: 1.0),
        GraphicsModeItem(id: "dos_ega", name: "DOS EGA 16-Color Palette", platformId: "dos_ega", colorDepthBits: 4, scaleFactor: 1.0),
        GraphicsModeItem(id: "dos_cga", name: "DOS CGA 4-Color Palette", platformId: "dos_ega", colorDepthBits: 2, scaleFactor: 1.0),
        GraphicsModeItem(id: "snes_vdp", name: "SNES Mode 2 / Mode 7 Graphics", platformId: "snes", colorDepthBits: 8, scaleFactor: 1.0),
        GraphicsModeItem(id: "genesis_vdp", name: "Sega Genesis 64-Color VDP", platformId: "genesis", colorDepthBits: 6, scaleFactor: 1.0),
        GraphicsModeItem(id: "arcade_hud", name: "Arcade High-Res RGB HUD", platformId: "arcade", colorDepthBits: 8, scaleFactor: 1.0),
        GraphicsModeItem(id: "c64_vicii", name: "Commodore 64 VIC-II Graphics", platformId: "c64", colorDepthBits: 4, scaleFactor: 1.0),
        GraphicsModeItem(id: "spectrum_attr", name: "ZX Spectrum Attribute-Clash Graphics", platformId: "spectrum", colorDepthBits: 3, scaleFactor: 1.0),
    ]

    public init() {}
}
