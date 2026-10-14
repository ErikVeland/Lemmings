import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkSkillPause(typography: GameMenuTypography, output: URL) throws {
        var captures = 0
        for (pose, size) in [("narrow", CGSize(width: 320, height: 548)),
                             ("landscape", CGSize(width: 568, height: 300)),
                             ("ipad", CGSize(width: 834, height: 1092))] {
            for interface in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(interface, width: size.width)
                var kept = MobileSettings(); kept.chooseSkillSelectionPause(true)
                var disabled = MobileSettings(); disabled.chooseSkillSelectionPause(false)
                let states = [("choice", MobileSettingsArt.skillSelectionPauseChoice()),
                              ("kept", MobileSettingsArt.page(.gameplay, settings: kept)),
                              ("off", MobileSettingsArt.page(.gameplay, settings: disabled))]
                for (state, page) in states {
                    let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                    if state == "choice" {
                        guard layout.targets.map(\.action.id) == ["1", "0"],
                              layout.targets.filter({ $0.action.primary }).map(\.action.id) == ["0"],
                              typography.width(of: page.subtitle, face: .small, scale: 1) <= layout.subtitle.width
                        else { throw Failure.invalidTargets }
                    }
                    for (index, target) in layout.targets.enumerated() {
                        guard target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                              layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                              layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) })
                        else { throw Failure.invalidTargets }
                        if state == "choice" {
                            guard typography.width(of: target.action.title, face: .small, scale: 1)
                                <= target.frame.width - (target.action.primary ? 48 : 24) else { throw Failure.invalidTargets }
                        }
                    }
                    guard layout.action(at: CGPoint(x: layout.board.minX + 2, y: layout.board.midY)) == nil
                    else { throw Failure.invalidTargets }
                    // Full canvas exports include Settings rows that require scrolling on the phone.
                    let height = Int(ceil(layout.size.height * scale))
                    guard let context = CGContext(data: nil, width: Int(size.width), height: height, bitsPerComponent: 8,
                        bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
                    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: scale, y: -scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                    guard let image = context.makeImage(),
                          let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("\(pose)-\(interface.rawValue)-\(state).png") as CFURL,
                            "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                    captures += 1
                }
            }
        }
        print("PASS: \(captures) skill-pause choice and Settings renders; targets and gaps validated; no windows or audio.")
    }
}
