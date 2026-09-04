import Foundation

/// The front-end artwork the Macintosh release carries.
///
/// The Macintosh version drew at twice the resolution of the other platforms,
/// and it ships the pieces the DOS release keeps inside sections that are not
/// decoded yet: two complete character sets, the title logo and the publisher
/// screen. A menu drawn from these is the game's own artwork rather than an
/// imitation of it in a system font.
///
/// Both character sets are monospaced. Every printable character from space to
/// tilde has a glyph, and space alone is blank.
public struct ClassicMacUserInterface: Sendable {
    /// The two character sets. The release carries a small face and a large
    /// one, and the front end uses both: the large face for menu titles and
    /// choices, the small face for status lines.
    public enum Face: String, Sendable, CaseIterable {
        case small = "Charset1"
        case large = "Charset2"
    }

    /// A monospaced character set, indexed from space.
    public struct Font: Sendable {
        /// The first character the set covers. Everything below it is control
        /// codes, which a menu never draws.
        public static let firstCharacter: Unicode.Scalar = " "
        public static let lastCharacter: Unicode.Scalar = "~"

        /// One cell, in Macintosh pixels. Twice the classic simulation's.
        public let cellWidth: Int
        public let cellHeight: Int
        /// Glyphs in character order, starting at space. A blank entry draws
        /// nothing and still advances one cell.
        public let glyphs: [ClassicMacArtwork.Frame?]

        init?(frames: [ClassicMacArtwork.Frame?]) {
            let first = Int(Font.firstCharacter.value)
            let last = Int(Font.lastCharacter.value)
            let covered = last - first + 1
            guard frames.count >= covered else { return nil }
            let printable = Array(frames[0..<covered])
            let present = printable.compactMap { $0 }
            guard present.count >= covered - 1 else { return nil }
            cellWidth = present.map { $0.x + $0.width }.max() ?? 0
            cellHeight = present.map { $0.y + $0.height }.max() ?? 0
            guard cellWidth > 0, cellHeight > 0 else { return nil }
            glyphs = printable
        }

        /// The glyph for a character, or nil when the set does not cover it.
        ///
        /// A character outside the set advances a cell and draws nothing, so a
        /// stray dash or ellipsis leaves a gap instead of breaking the line.
        public func glyph(for character: Character) -> ClassicMacArtwork.Frame? {
            guard let scalar = character.unicodeScalars.first,
                character.unicodeScalars.count == 1,
                scalar >= Font.firstCharacter, scalar <= Font.lastCharacter
            else { return nil }
            return glyphs[Int(scalar.value) - Int(Font.firstCharacter.value)]
        }

        /// Whether the set covers every character in the text.
        public func covers(_ text: String) -> Bool {
            text.allSatisfy { character in
                guard let scalar = character.unicodeScalars.first,
                    character.unicodeScalars.count == 1
                else { return false }
                return scalar >= Font.firstCharacter && scalar <= Font.lastCharacter
            }
        }

        /// The width of a line, in Macintosh pixels, at a whole-number scale.
        public func width(of text: String, scale: Int = 1) -> Int {
            text.count * cellWidth * scale
        }

        public func height(scale: Int = 1) -> Int { cellHeight * scale }
    }

    public let fonts: [Face: Font]
    /// The title logo, in colour.
    public let logo: ClassicMacArtwork.Frame?
    /// The publisher screen shown before the title.
    public let publisher: ClassicMacArtwork.Frame?
    /// The status bar artwork, including the skill buttons.
    public let icons: [ClassicMacArtwork.Frame?]

    /// Reads the front-end banks out of a release's artwork.
    ///
    /// Returns nil when the release carries no character set, because a front
    /// end with no font cannot draw anything.
    public init?(artwork: ClassicMacArtwork) {
        var fonts: [Face: Font] = [:]
        for face in Face.allCases {
            guard let bank = artwork.bank(named: face.rawValue),
                let frames = artwork.banks[bank],
                let font = Font(frames: frames)
            else { continue }
            fonts[face] = font
        }
        guard !fonts.isEmpty else { return nil }
        self.fonts = fonts

        // The releases carry two sizes of each picture. The larger one is the
        // one the Macintosh actually showed.
        logo = artwork.bank(named: "Logo2").flatMap { artwork.frame($0) }
            ?? artwork.bank(named: "Logo1").flatMap { artwork.frame($0) }
        publisher = artwork.bank(named: "Psygnosis2").flatMap { artwork.frame($0) }
            ?? artwork.bank(named: "Psygnosis1").flatMap { artwork.frame($0) }
        icons = artwork.bank(named: "Icons").flatMap { artwork.banks[$0] } ?? []
    }

    public func font(_ face: Face) -> Font? { fonts[face] }
}
