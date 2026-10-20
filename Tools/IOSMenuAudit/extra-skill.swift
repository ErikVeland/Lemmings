import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkExtraSkill(typography: GameMenuTypography, output: URL) throws {
        let choices: [(String, [MobileExtraSkillChoice])] = [
            ("classic", ClassicSkill.allCases.enumerated().map {
                .init(skillID: $0.element.rawValue, title: SkillVocabulary.title($0.element.rawValue), control: $0.offset)
            }),
            ("lemmings2", ["Jumper", "Platformer", "Club Basher", "Flame Thrower", "Laser Blaster", "Superlem", "Hopper", "Roper"].enumerated().map {
                .init(skillID: $0.element.lowercased(), title: $0.element, control: $0.offset)
            }),
            ("lemmings3", ["Bricks", "Spade", "Grenade", "Swimmer"].enumerated().map {
                .init(skillID: $0.element.lowercased(), title: "\($0.element) - Lemming \($0.offset + 20)", control: 3, target: $0.offset + 19)
            })
        ]
        let devices: [(String, CGSize, Bool)] = [("phone", .init(width: 390, height: 763), false),
            ("phone-landscape", .init(width: 568, height: 300), false),
            ("tablet", .init(width: 1194, height: 834), false), ("tv", .init(width: 1920, height: 1080), true)]
        var captures = 0
        for (game, options) in choices {
            let chooser = MobileExtraSkillArt.page(options)
            guard chooser.rows.count == options.count, chooser.backAction?.id == "0",
                  zip(chooser.rows, options).allSatisfy({ pair in pair.0.title == "+1 " + pair.1.title }) else { throw invalidTargets(line: #line) }
            var earned = GameFrontEnd.Page(title: "Level complete", subtitle: game,
                details: ["Saved 80/80   Goal 40", "Time 0:42.00", "+1 SUPERZOOM", "+1 LEVEL SKIP", "RARE: +1 EXTRA SKILL"],
                footer: [.init("next", "NEXT LEVEL", primary: true), .init("retry", "RETRY"), .init("back", "BACK")])
            earned.result = true
            var bonus = GameFrontEnd.Page(title: "Level complete", subtitle: game,
                details: ["Saved 80/80   Goal 40", "Time 0:42.00", "Bonus skill used"],
                footer: [.init("next", "NEXT LEVEL", primary: true), .init("retry", "RETRY"), .init("back", "BACK")])
            bonus.result = true
            for (state, page) in [("choose", chooser), ("earned", earned), ("bonus", bonus)] {
                for (device, viewport, television) in devices {
                    for setting in ClassicInterfaceSize.allCases {
                        let scale = MobileSettingsArt.interfaceScale(setting, width: viewport.width, television: television)
                        let layout = GameFrontEnd.layout(page, width: viewport.width / scale, minimumHeight: viewport.height / scale)
                        let canvas = CGRect(origin: .zero, size: layout.size)
                        guard layout.details.count == page.details.count, layout.details.allSatisfy({ canvas.contains($0) }),
                              layout.targets.count == page.rows.count + page.footer.count,
                              Set(layout.targets.map { $0.action.id }).count == layout.targets.count else { throw invalidTargets(line: #line) }
                        for (index, target) in layout.targets.enumerated() {
                            let scroll = min(max(0, layout.size.height * scale - viewport.height),
                                max(0, target.frame.midY * scale - viewport.height / 2))
                            let visible = CGRect(x: 0, y: scroll, width: viewport.width, height: viewport.height)
                            let scaled = CGRect(x: target.frame.minX * scale, y: target.frame.minY * scale,
                                width: target.frame.width * scale, height: target.frame.height * scale)
                            guard target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                                  canvas.contains(target.frame), visible.contains(scaled),
                                  !layout.targets.dropFirst(index + 1).contains(where: { $0.frame.intersects(target.frame) }),
                                  layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == target.action.id
                            else { throw invalidTargets(line: #line) }
                        }
                        let size = CGSize(width: ceil(layout.size.width * scale), height: ceil(layout.size.height * scale))
                        let context = try bitmapContext(size: size)
                        context.scaleBy(x: scale, y: scale)
                        GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                        try save(context: context, to: output.appendingPathComponent("\(game)-\(state)-\(device)-\(setting).png"))
                        captures += 1
                    }
                }
            }
        }
        print("PASS \(captures) extra-skill choice, earned receipt and bonus result captures with target checks")
    }
}
