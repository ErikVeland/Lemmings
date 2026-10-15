import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkStaticHome(typography: GameMenuTypography, output: URL) throws {
        var captures = 0
        for (device, size, television) in [("phone", CGSize(width: 320, height: 548), false),
            ("tablet", CGSize(width: 1366, height: 1024), false),
            ("tv", CGSize(width: 1920, height: 1080), true)] {
            for interface in ClassicInterfaceSize.allCases {
                for enabled in [false, true] {
                    var settings = MobileSettings()
                    settings.classic.staticHomeScreen = enabled
                    let restored = try JSONDecoder().decode(MobileSettings.self, from: JSONEncoder().encode(settings))
                    guard restored.classic.staticHomeScreen == enabled, !restored.classic.reduceMotion,
                          restored.classic.speedEffectsEnabled else { throw invalidTargets(line: #line) }
                    let page = MobileSettingsArt.page(.accessibility, settings: restored)
                    guard let toggle = page.rows.first(where: { $0.id == "setting.staticHome" }),
                          toggle.selected == enabled, toggle.title == L10n.text("Static home screen")
                    else { throw invalidTargets(line: #line) }
                    let scale = MobileSettingsArt.interfaceScale(interface, width: size.width, television: television)
                    let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                    for (index, target) in layout.targets.enumerated() {
                        guard target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                              layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                              layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) })
                        else { throw invalidTargets(line: #line) }
                    }
                    let context = try bitmapContext(size: CGSize(width: size.width, height: ceil(layout.size.height * scale)))
                    context.scaleBy(x: scale, y: scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                    try save(context: context, to: output.appendingPathComponent("\(device)-\(interface.rawValue)-\(enabled).png"))
                    captures += 1
                }
            }
        }
        print("PASS: \(captures) Static Home Settings renders, toggle states, input targets and saved settings; no windows or audio.")
    }
}
