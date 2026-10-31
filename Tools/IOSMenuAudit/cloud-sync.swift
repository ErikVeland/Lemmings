import Foundation
import CoreGraphics
import ImageIO
import LemmingsGameArt

extension MenuAudit {
    @MainActor static func checkCloudSync(typography: GameMenuTypography, output: URL) throws {
        let pages: [(String, GameFrontEnd.Page)] = [
            ("automatic", CloudSyncArt.page(status: "Synced")),
            ("offline", CloudSyncArt.page(status: "Offline")),
            ("busy", CloudSyncArt.page(busy: true)),
            ("code", CloudSyncArt.page(code: "ABCD2345EFGH")),
            ("entry", CloudSyncArt.page(draft: "ABCD2345EFGH")),
            ("empty", CloudSyncArt.page(draft: "")),
            ("expired", CloudSyncArt.page(message: "This code expired or was used. Create a new code on your other device.", draft: "ABCD2345EFGH")),
            ("tester", CloudSyncArt.page(testerEnabled: true))]
        for (device, width, height) in [("mac", 1120, 720), ("iphone", 390, 763), ("narrow", 320, 548),
                                        ("ipad", 1024, 1366), ("duo", 720, 540), ("tv", 1920, 1080)] {
            for (name, page) in pages {
                let layout = GameFrontEnd.layout(page, width: CGFloat(width), minimumHeight: CGFloat(height))
                guard layout.targets.filter({ $0.action.enabled && $0.action.primary }).count <= 1 else { throw invalidTargets(line: #line) }
                for target in layout.targets {
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          CGRect(origin: .zero, size: layout.size).contains(target.frame),
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                    else { throw invalidTargets(line: #line) }
                }
                guard let context = CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                    bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw invalidTargets(line: #line) }
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: nil, in: context)
                guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                    output.appendingPathComponent("\(device)-\(name).png") as CFURL, "public.png" as CFString, 1, nil)
                else { throw invalidTargets(line: #line) }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { throw invalidTargets(line: #line) }
            }
        }
        print("PASS 48 cloud-link bitmap captures and matching input targets")
    }
}
