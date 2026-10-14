import Foundation
import CoreGraphics
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    static func checkBuildChanges(typography: GameMenuTypography, manifest: URL, output: URL) throws {
        let info = try JSONDecoder().decode(MobileBuildInfo.self, from: Data(contentsOf: manifest))
        let changes = MobileInformationArt.whatsNew(build: info)
        let families: [GameFrontEnd.Action] = MobileFamily.allCases.map {
            .init("family." + $0.rawValue, $0.title)
        } + [.init("neolemmix", "NeoLemmix Preview"), .init("l2", "Lemmings 2", gameLogo: .lemmings2),
                .init("l3", "Lemmings 3", gameLogo: .lemmings3)]
        let home = MobileHomeArt.page(journey: .init("journey", "Journey map"), families: families,
            initials: "LEM", subtitle: [info.label, info.dateLabel].joined(separator: "\n"))
        let fallback = MobileInformationArt.whatsNew(build: .init(version: "2.0", build: "2",
            identity: "fallback", builtAt: "", changes: []))
        var captures = 0
        for (name, page) in [("latest", changes), ("home", home), ("fallback", fallback)] {
            for setting in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(setting, width: 1920, television: true)
                let layout = GameFrontEnd.layout(page, width: 1920 / scale, minimumHeight: 1080 / scale)
                let bounds = CGRect(origin: .zero, size: layout.size)
                for target in layout.targets {
                    guard bounds.contains(target.frame), target.frame.width * scale >= 44,
                          target.frame.height * scale >= 44,
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                          !target.frame.intersects(layout.subtitle),
                          layout.details.allSatisfy({ !target.frame.intersects($0) }) else { throw Failure.invalidTargets }
                }
                for (index, target) in layout.targets.enumerated() {
                    guard layout.targets.dropFirst(index + 1).allSatisfy({ !target.frame.intersects($0.frame) })
                        else { throw Failure.invalidTargets }
                }
                if !page.home {
                    guard layout.targets.count == 1, layout.targets[0].action.id == "welcomeContinue",
                          layout.targets[0].action.primary else { throw Failure.invalidTargets }
                }
                for focused in [false, true] {
                    guard let context = CGContext(data: nil, width: Int(layout.size.width * scale),
                        height: Int(layout.size.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                        else { throw Failure.missingArtwork }
                    context.translateBy(x: 0, y: layout.size.height * scale)
                    context.scaleBy(x: scale, y: -scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography,
                        highlighted: focused ? layout.targets.first?.action.id : nil, in: context)
                    guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                        output.appendingPathComponent("\(name)-\(Int(scale))-\(focused ? "focused" : "idle").png") as CFURL,
                        "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                    captures += 1
                }
            }
        }
        print("PASS: \(captures) TV build pages, input bounds, focus states and three interface sizes; windowless and muted.")
    }
}
