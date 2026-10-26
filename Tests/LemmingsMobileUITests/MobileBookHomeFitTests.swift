import CoreGraphics
import Testing
import LemmingsGameArt

struct MobileBookHomeFitTests {
    private func page(resume: Bool, hotSeat: Bool) -> GameFrontEnd.Page {
        MobileHomeArt.page(resume: resume ? [.init("resume", "Resume Journey")] : [],
            journey: .init("journey", "Journey map 1/227 solved"), families: [
                .init("family.classic", "Classic Lemmings 0/120"),
                .init("family.ohNo", "Oh No! More Lemmings 0/100"),
                .init("family.holiday", "Holiday Lemmings 0/72"),
                .init("family.ohYes", "Oh Yes! More Lemmings 0/60"),
                .init("family.fan", "Fan Lemmings 0/6016"),
                .init("neolemmix", "NeoLemmix Preview"),
                .init("l2", "Lemmings 2", gameLogo: .lemmings2),
                .init("l3", "Lemmings 3", gameLogo: .lemmings3)],
            initials: hotSeat ? "ALICE v BOB" : "PLA", nextPlayerIndex: hotSeat ? 0 : nil,
            subtitle: hotSeat ? "" : "Next: PLA", deskClock: true)
    }

    @Test func standardOpenDuoHomeFitsWithoutScrolling() {
        for size in [CGSize(width: 1194, height: 650), .init(width: 1194, height: 794),
                     .init(width: 834, height: 1154)] {
            let half = (size.width - 16) / 2
            let panes = [CGRect(x: 0, y: 0, width: half, height: size.height),
                         CGRect(x: half + 16, y: 0, width: half, height: size.height)]
            for resume in [false, true] {
                for hotSeat in [false, true] {
                    let page = page(resume: resume, hotSeat: hotSeat)
                    let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height,
                        boxedHome: true, bookHomePanes: panes)
                    #expect(layout.size == size, "\(size), resume: \(resume), Hot Seat: \(hotSeat)")
                    #expect(Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map { $0.id }))
                    #expect(layout.targets.filter { $0.action.primary }.count == 1)
                    for (index, target) in layout.targets.enumerated() {
                        #expect(CGRect(origin: .zero, size: size).contains(target.frame))
                        #expect(panes.contains { $0.contains(target.frame) })
                        #expect(target.frame.maxY <= size.height - 20)
                        #expect(target.frame.width >= 44 && target.frame.height >= 44)
                        #expect(layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                        #expect(layout.targets.dropFirst(index + 1).allSatisfy { !$0.frame.intersects(target.frame) })
                    }
                }
            }
        }
    }

    @Test func insufficientHeightKeepsEveryActionReachableByScrolling() {
        let page = page(resume: true, hotSeat: false)
        let panes = [CGRect(x: 0, y: 0, width: 318, height: 425),
                     CGRect(x: 332, y: 0, width: 318, height: 425)]
        let layout = GameFrontEnd.layout(page, width: 650, minimumHeight: 425, bookHomePanes: panes)
        #expect(layout.size.height > 425)
        #expect(Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map { $0.id }))
        #expect(layout.targets.allSatisfy { CGRect(origin: .zero, size: layout.size).contains($0.frame) })
    }
}
