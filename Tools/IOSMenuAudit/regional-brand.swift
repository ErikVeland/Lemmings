import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkRegionalBrand(typography: GameMenuTypography, resources: URL, output: URL) throws {
        for identifier in ["en_US", "es_US", "fr_US"] {
            guard Lemmings3Brand(regionCode: Locale(identifier: identifier).regionCode) == .chronicles else {
                throw invalidTargets(line: #line)
            }
        }
        for region in ["AU", "GB", "CA", "FR", "JP", "", nil] {
            guard Lemmings3Brand(regionCode: region) == .allNewWorld else { throw invalidTargets(line: #line) }
        }
        guard Lemmings3Brand(regionCode: "us") == .chronicles,
              ClassicTitle.lemmings3TheChronicles.rawValue == "lemmings3TheChronicles",
              ClassicTitle.lemmings3TheChronicles.displayName == Lemmings3Brand.current.displayName,
              MobileGameDataKind.lemmings3.displayTitle == Lemmings3Brand.current.displayName,
              GameHomeLogoArt(resources: nil, brand: .chronicles).image(.lemmings3) == nil else {
            throw invalidTargets(line: #line)
        }
        let sizes: [(String, CGSize, Bool)] = [
            ("mac-compact", .init(width: 900, height: 620), false),
            ("mac-large", .init(width: 5110, height: 2878), false),
            ("ipad-landscape", .init(width: 1366, height: 1024), false),
            ("ipad-portrait", .init(width: 1024, height: 1366), false),
            ("tv-1080", .init(width: 1920, height: 1080), true),
            ("tv-4k", .init(width: 3840, height: 2160), true)]
        var captures = 0
        var pixels: [Data] = []
        for (region, expected, dimensions) in [("US", "The Lemmings Chronicles", CGSize(width: 222, height: 144)),
                                                ("AU", "All New World of Lemmings", CGSize(width: 288, height: 154))] {
            let brand = Lemmings3Brand(regionCode: region)
            let logos = GameHomeLogoArt(resources: resources, brand: brand)
            guard brand.displayName == expected, let logo = logos.image(.lemmings3),
                  CGSize(width: logo.width, height: logo.height) == dimensions,
                  let data = logo.dataProvider?.data else { throw invalidTargets(line: #line) }
            pixels.append(data as Data)
            let type = GameMenuTypography(interface: typography.interface, homeLogos: logos)
            for (device, size, television) in sizes {
                for interface in ClassicInterfaceSize.allCases {
                    let scale = MobileSettingsArt.interfaceScale(interface, width: size.width, television: television)
                    let viewport = CGSize(width: size.width / scale, height: size.height / scale)
                    let families: [GameFrontEnd.Action] = [
                        .init("classic", "Classic Lemmings"), .init("ohno", "Oh No! More Lemmings"),
                        .init("holiday", "Holiday Lemmings"), .init("ohyes", "Oh Yes! More Lemmings!"),
                        .init("fan", "Fan Lemmings"), .init("neo", "NeoLemmix"),
                        .init("l2", "Lemmings 2", gameLogo: .lemmings2),
                        .init("l3", brand.displayName, gameLogo: .lemmings3)]
                    let page = MobileHomeArt.page(journey: .init("journey", "Journey map"), families: families, initials: "LEM")
                    let layout = GameFrontEnd.layout(page, width: viewport.width, minimumHeight: viewport.height, boxedHome: true)
                    guard let target = layout.targets.first(where: { $0.action.id == "l3" }),
                          target.action.title == expected, target.action.gameLogo == .lemmings3,
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == "l3" else {
                        throw invalidTargets(line: #line)
                    }
                    for (index, target) in layout.targets.enumerated() {
                        guard layout.board.contains(target.frame), target.frame.width >= 44, target.frame.height >= 44,
                              !layout.targets.dropFirst(index + 1).contains(where: { target.frame.intersects($0.frame) }) else {
                            throw invalidTargets(line: #line)
                        }
                    }
                    guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                        bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw invalidTargets(line: #line) }
                    context.translateBy(x: 0, y: size.height); context.scaleBy(x: scale, y: -scale)
                    let scroll = max(0, target.frame.maxY - viewport.height + 8)
                    context.translateBy(x: 0, y: -scroll)
                    GameFrontEnd.draw(page, layout: layout, typography: type, highlighted: "l3", in: context)
                    guard let rendered = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                        output.appendingPathComponent("\(region)-\(device)-\(interface.rawValue).png") as CFURL,
                        "public.png" as CFString, 1, nil) else { throw invalidTargets(line: #line) }
                    CGImageDestinationAddImage(destination, rendered, nil)
                    guard CGImageDestinationFinalize(destination) else { throw invalidTargets(line: #line) }
                    captures += 1
                }
            }
        }
        guard pixels[0] != pixels[1] else { throw invalidTargets(line: #line) }
        print("PASS regional release titles and original logos: \(captures) Home captures, accessible names and input targets")
    }
}
