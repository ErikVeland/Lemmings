import Foundation

/// Permanent-skill markers shared by the Mac and mobile monochrome renderers.
public enum ClassicMonochromeBackpack {
    public enum Kind: String, CaseIterable, Sendable {
        case climber, floater, both

        public static func assigned(climber: Bool, floater: Bool) -> Self? {
            climber ? (floater ? .both : .climber) : (floater ? .floater : nil)
        }
    }

    /// Anatomy measured from the matching colour frame, in monochrome frame coordinates.
    public struct Guide: Codable, Sendable {
        public let top: Int
        public let left: Int
        public let right: Int
        public let foreground: [Int]
    }

    public static func render(_ frame: ClassicMacArtwork.Frame, kind: Kind?,
        pose: ClassicLemmingPose, left: Bool) -> ClassicMacArtwork.Frame {
        switch pose {
        case .drowning, .splatting, .frying, .explosion, .exiting: return frame
        default: break
        }
        guard let kind, let guide = frame.backpackGuide else { return frame }
        let packWidth = 6, packHeight = 8
        let padding = max(packWidth, packWidth - guide.left, guide.right + packWidth + 1 - frame.width)
        let width = frame.width + padding * 2
        var pixels = [UInt8](repeating: 0, count: width * frame.height * 4)
        for y in 0..<frame.height {
            let source = y * frame.width * 4
            let target = (y * width + padding) * 4
            pixels.replaceSubrange(target..<target + frame.width * 4,
                with: frame.rgba[source..<source + frame.width * 4])
        }
        let backFacesRight = (pose == .floating || pose == .umbrellaOpening) ? !left : left
        let origin = padding + (backFacesRight ? guide.right + 1 : guide.left - packWidth)
        let top = max(0, min(guide.top, frame.height - packHeight))
        let foreground = Set(guide.foreground)
        for dy in 0..<packHeight {
            let y = top + dy
            guard (0..<frame.height).contains(y) else { continue }
            for dx in 0..<packWidth {
                let x = origin + dx
                guard (0..<width).contains(x) else { continue }
                let sourceX = x - padding
                if (0..<frame.width).contains(sourceX),
                    foreground.contains(y * frame.width + sourceX),
                    frame.rgba[(y * frame.width + sourceX) * 4 + 3] != 0 { continue }
                // Keep the pattern fixed to the pack as the actor moves and turns.
                let patternX = backFacesRight ? packWidth - 1 - dx : dx
                let white: Bool
                switch kind {
                case .climber: white = (patternX + dy) % 4 < 2
                case .floater: white = dy % 2 == 0
                case .both: white = (patternX + dy) % 2 == 0
                }
                let rim = patternX == 0 || dy == 0 || dy == packHeight - 1
                let value: UInt8 = white || rim ? 255 : 0
                let p = (y * width + x) * 4
                pixels[p] = value; pixels[p + 1] = value; pixels[p + 2] = value
                pixels[p + 3] = 255
            }
        }
        return ClassicMacArtwork.Frame(x: frame.x - padding, y: frame.y,
            width: width, height: frame.height, rgba: Data(pixels))
    }
}
