import CoreGraphics
import CoreImage
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkSupport(typography: GameMenuTypography, output: URL) throws {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(options: [.useSoftwareRenderer: true]),
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        func scans(_ image: CGImage) -> Bool {
            let scale = max(1, 300 / CGFloat(image.width))
            return detector.features(in: CIImage(cgImage: image).transformed(by: .init(scaleX: scale, y: scale)))
                .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
                .contains(GameSupport.coffeeURL.absoluteString)
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
                for available in [true, false] {
                    var page = MobileHomeArt.page(resume: [.init("resume", "Resume journey")],
                        journey: .init("journey", "Journey map 1/227 solved"), families: [
                            .init("family.classic", "Classic Lemmings 0/120"),
                            .init("family.ohNo", "Oh No! More Lemmings 0/100"),
                            .init("family.holiday", "Holiday Lemmings 0/72"),
                            .init("family.fan", "Fan Lemmings 0/6020"),
                            .init("l2", "Lemmings 2"), .init("l3", "All New World of Lemmings")],
                        initials: "PLA", collectionsAvailable: available, deskClock: !tv)
                    if tv { page = TVMenuPresentation.homePage(page) }
                    var scale = MobileSettingsArt.interfaceScale(interface, width: size.width, television: tv)
                    if tv { scale = TVMenuPresentation.homeScale(scale, page: page, width: size.width, height: size.height) }
                    let viewport = CGSize(width: size.width / scale, height: size.height / scale)
                    let layout = tv ? TVMenuPresentation.homeLayout(page, width: viewport.width, height: viewport.height)
                        : GameFrontEnd.layout(page, width: viewport.width, minimumHeight: viewport.height, boxedHome: true)
                    guard let donate = layout.targets.first(where: { $0.action.id == "donate" }),
                          donate.action.enabled, !donate.action.primary,
                          layout.targets.filter({ $0.action.primary }).count == 1,
                          layout.action(at: CGPoint(x: donate.frame.midX, y: donate.frame.midY)) == "donate"
                    else { throw invalidTargets(line: #line) }
                    let scroll = tv ? 0 : max(0, min(layout.size.height - viewport.height, donate.frame.maxY - viewport.height + 12))
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
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: qr, highlighted: "home", in: context)
                try save(context: context, to: output.appendingPathComponent("\(pose)-\(interface.rawValue)-qr.png"))
                let previewFrame = layout.preview.offsetBy(dx: 0, dy: -scroll).applying(.init(scaleX: scale, y: scale))
                guard let image = context.makeImage(), let renderedCode = image.cropping(to: previewFrame.integral) else { throw invalidTargets(line: #line) }
                let decoded = scans(renderedCode)
                guard decoded,
                      let back = layout.targets.first(where: { $0.action.id == "home" }),
                      layout.action(at: CGPoint(x: back.frame.midX, y: back.frame.midY)) == "home",
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
