import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkSupport(typography: GameMenuTypography, output: URL) throws {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(options: [.useSoftwareRenderer: true]),
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        func scans(_ image: CGImage) -> Bool {
            let scale = max(1, 300 / CGFloat(image.width))
            let native = detector?.features(in: CIImage(cgImage: image).transformed(by: .init(scaleX: scale, y: scale)))
                .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
                .contains(GameSupport.coffeeURL.absoluteString)
            if native == true { return true }
            guard let executable = ProcessInfo.processInfo.environment["LEMMINGS_QR_SCANNER"] else { return false }
            let file = output.appendingPathComponent("scan-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: file) }
            guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { return false }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return false }
            let scanner = Process(), pipe = Pipe()
            scanner.executableURL = URL(fileURLWithPath: executable)
            scanner.arguments = ["--quiet", "--raw", file.path]
            scanner.standardOutput = pipe
            guard (try? scanner.run()) != nil else { return false }
            let decoded = pipe.fileHandleForReading.readDataToEndOfFile()
            scanner.waitUntilExit()
            return scanner.terminationStatus == 0 && String(decoding: decoded, as: UTF8.self)
                .split(whereSeparator: \.isNewline).contains(Substring(GameSupport.coffeeURL.absoluteString))
        }
        guard let qr = GameSupport.qrCode, scans(qr) else { throw invalidTargets(line: #line) }
        let poses: [(String, CGSize, Bool)] = [
            ("phone", .init(width: 390, height: 760), false),
            ("phone-landscape", .init(width: 760, height: 350), false),
            ("tablet", .init(width: 834, height: 1110), false),
            ("tablet-landscape", .init(width: 1194, height: 790), false),
            ("tv-720", .init(width: 1152, height: 648), true),
            ("tv-1080", .init(width: 1728, height: 972), true)]
        var captures = 0
        for (pose, size, tv) in poses {
            for interface in ClassicInterfaceSize.allCases {
                for available in [true] {
                    // Donate lives with the other About actions in Settings.
                    var page = MobileSettingsArt.groups(television: tv)
                    page.footer += MobileSettingsArt.aboutActions
                    let scale = MobileSettingsArt.interfaceScale(interface, width: size.width, television: tv)
                    let viewport = CGSize(width: size.width / scale, height: size.height / scale)
                    let layout = GameFrontEnd.layout(page, width: viewport.width, minimumHeight: viewport.height)
                    guard let donate = layout.targets.first(where: { $0.action.id == "donate" }),
                          donate.action.enabled, !donate.action.primary,
                          layout.action(at: CGPoint(x: donate.frame.midX, y: donate.frame.midY)) == "donate"
                    else { throw invalidTargets(line: #line) }
                    let scroll = max(0, min(layout.size.height - viewport.height, donate.frame.maxY - viewport.height + 12))
                    guard CGRect(origin: .zero, size: viewport).contains(donate.frame.offsetBy(dx: 0, dy: -scroll)),
                          donate.frame.width * scale >= 44, donate.frame.height * scale >= 44,
                          layout.targets.filter({ $0.action.id != "donate" }).allSatisfy({ !donate.frame.intersects($0.frame) })
                    else { throw invalidTargets(line: #line) }
                    let context = try bitmapContext(size: size)
                    context.scaleBy(x: scale, y: scale); context.translateBy(x: 0, y: -scroll)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "donate", in: context)
                    try save(context: context, to: output.appendingPathComponent("\(pose)-\(interface.rawValue)-\(available).png"))
                    captures += 1
                }
                let page = MobileTurnArt.page(GameSupport.page, playerName: "PLA", role: .next, sessionName: nil)
                let scale = GameSupport.fittedScale(MobileSettingsArt.interfaceScale(interface, width: size.width, television: tv),
                    page: page, width: size.width, height: size.height)
                let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                let viewport = CGSize(width: size.width / scale, height: size.height / scale)
                let scroll = max(0, min(layout.size.height - viewport.height, layout.preview.midY - viewport.height / 2))
                let context = try bitmapContext(size: size)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: 0, y: -scroll)
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: qr, highlighted: "settings", in: context)
                try save(context: context, to: output.appendingPathComponent("\(pose)-\(interface.rawValue)-qr.png"))
                let previewFrame = layout.preview.offsetBy(dx: 0, dy: -scroll).applying(.init(scaleX: scale, y: scale))
                guard let image = context.makeImage(), let renderedCode = image.cropping(to: previewFrame.integral) else { throw invalidTargets(line: #line) }
                let decoded = scans(renderedCode) || scans(image)
                guard decoded,
                      let back = layout.targets.first(where: { $0.action.id == "settings" }),
                      layout.action(at: CGPoint(x: back.frame.midX, y: back.frame.midY)) == "settings",
                      CGRect(origin: .zero, size: viewport).contains(back.frame.offsetBy(dx: 0, dy: -max(0, layout.size.height - viewport.height))),
                      layout.size.height <= viewport.height
                else {
                    print("Support failure: \(pose), \(interface.rawValue), scale \(scale), size \(layout.size), viewport \(viewport), QR decoded \(decoded), Back \(layout.targets.map(\.frame))")
                    let cropped = try bitmapContext(size: .init(width: renderedCode.width, height: renderedCode.height))
                    GameStoneArt.drawImage(renderedCode, in: CGRect(x: 0, y: 0, width: renderedCode.width, height: renderedCode.height), context: cropped)
                    try save(context: cropped, to: output.appendingPathComponent("qr-failure-crop.png"))
                    throw invalidTargets(line: #line)
                }
                captures += 1
            }
        }
        print("PASS: \(captures) donation renders; enabled secondary Home action, compact scrolling, target geometry, TV layout and QR decoding. Windowless and muted.")
    }
}
