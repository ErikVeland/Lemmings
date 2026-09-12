import AppKit
import NxlvKit

/// Shares the game's pixel headings, sprite portraits, input and page stack.
@MainActor extension ArcadeView {
    func drawStar(at origin: CGPoint, earned: Bool, size: CGFloat = 2) {
        GameStar.draw(at: origin, earned: earned, size: size)
    }

    func rescueSummary(_ run: ArcadeRun, maximum: TrolleyMaximum) -> String {
        "Rescued: \(run.saved). Required: \(run.level.required). "
        + (maximum.isRescueTarget ? "\(maximum.status == .verified ? "Best possible" : "Best known"): \(maximum.value.map(String.init) ?? "unknown")." : "Maximum rescue unknown.")
    }
    func drawRescueTargets(_ run: ArcadeRun, maximum: TrolleyMaximum) {
        text("Required  \(run.level.required)", 248, 350, 280, alignment: .center, alpha: 0.8)
        let target = maximum.isRescueTarget ? "\(maximum.status == .verified ? "Best possible" : "Best known")  \(maximum.value.map(String.init) ?? "?")" : "Maximum unknown"
        text(target, 552, 350, 320, alignment: .center, alpha: 0.8)
    }
    func drawGameResult(_ report: ArcadeReport) {
        drawCelebratedResult(report)
    }

    func drawTrolleyRecords(_ conditions: TrolleyConditions) {
        header(level?.title ?? "The Trolley"); tabs(); boardScopeLinks()
        let target = ArcadeStore.shared.records.trolley.maximum(conditions: conditions, assisted: assisted)
        let boardTitle = target.status == .record && trolleyBoard == .zeroAvoidableLosses ? "Record matched" : trolleyBoard.title
        let ordering = target.status == .record && [.rescuePotential, .zeroAvoidableLosses, .cleanRescue].contains(trolleyBoard)
            ? "Best-known target: \(target.value ?? 0) saved. Fewest skills, then fastest time."
            : trolleyBoard.ordering
        let categories = TrolleyBoard.allCases, index = categories.firstIndex(of: trolleyBoard) ?? 0
        button("‹", CGRect(x: 64, y: 212, width: 66, height: 44)) { [weak self] in
            self?.trolleyBoard = categories[(index + categories.count - 1) % categories.count]; self?.needsDisplay = true
        }
        text(boardTitle, 153, 218, 620)
        button("›", CGRect(x: 687, y: 212, width: 66, height: 44)) { [weak self] in
            self?.trolleyBoard = categories[(index + 1) % categories.count]; self?.needsDisplay = true
        }
        rewindFilter()
        let entries = ArcadeStore.shared.records.trolley.leaderboard(conditions: conditions, assisted: assisted, board: trolleyBoard)
        text("PLAYER", 181, 272, 96)
        text("PLAY STYLE", 280, 272, 304)
        text("RESULT", 589, 272, 220)
        text("SKILLS", 821, 272, 86, alignment: .right)
        text("TIME", 925, 272, 119, alignment: .right)
        for (index, attempt) in entries.prefix(5).enumerated() {
            let run = attempt.run, y = CGFloat(301 + index * 50)
            GameStyle.fill(CGRect(x: 64, y: y, width: 992, height: 49), run.profileID == player.id ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor.clear)
            let row = CGRect(x: 64, y: y, width: 992, height: 49)
            rowText("\(index + 1)", x: 79, width: 38, row: row)
            let profile = ArcadeStore.shared.records.profile(run.profileID)
            drawPortrait(profile?.portrait ?? 0, in: CGRect(x: 130, y: y + 4, width: 33, height: 38))
            rowText(profile?.initials ?? "LEM", x: 181, width: 72, row: row)
            affinityLink(attempt.philosophy.primaryID, in: CGRect(x: 280, y: y + 3, width: 304, height: 44), alignment: .left)
            let score: String
            switch trolleyBoard {
            case .rescuePotential: score = String(format: "%.1f%%", (attempt.metrics.rescuePotential ?? 0) * 100)
            case .moralSurplus: score = "+\(attempt.metrics.moralSurplus) extra"
            case .mostUsedSkill: score = run.mostUsedSkill.lowercased()
            default: score = "\(run.saved) saved"
            }
            rowText(score, x: 589, width: 220, row: row)
            rowText("\(run.skillCount)", x: 821, width: 86, row: row, alignment: .right)
            rowText(Self.time(run.seconds), x: 925, width: 119, row: row, alignment: .right)
        }
        if entries.isEmpty {
            text("No records", 64, 337, 992, alignment: .center)
        }
        let trophy = TrolleyAchievement.forBoard(trolleyBoard)
        let progress = trophy.progress(attempts: ArcadeStore.shared.records.trolley.attempts, profileID: player.id)
        link("Award: \(trophy.title) - \(progress.label)  >", CGRect(x: 64, y: 549, width: 992, height: 36)) { [weak self] in
            self?.showAchievement(trophy)
        }
        pageFooter()
        setAccessibilityLabel("\(boardTitle). Rewinds: \(assisted ? "used" : "unused"). W switches the rewind filter. \(entries.count) local records. \(ordering) Related achievement: \(trophy.title). \(trophy.detail) \(progress.label). Press 1 to 7 to choose a board. Escape returns.")
    }

    private func achievementPriority(_ award: TrolleyAchievement) -> Int {
        switch award.tier { case .legendary: 4; case .gold: 3; case .silver: 2; case .bronze: 1 }
    }
    private var orderedHighlightedAwards: [TrolleyAchievement] {
        highlightedAwards.sorted {
            let left = achievementPriority($0), right = achievementPriority($1)
            return left == right ? $0.rawValue < $1.rawValue : left > right
        }
    }
    func showNewAwards() {
        highlightedAwards = Set(report?.trolley?.attempt.achievements ?? [])
        focusedNewAward = nil
        showAchievement(orderedHighlightedAwards.first)
    }
    func showAchievement(_ award: TrolleyAchievement?) {
        if let award {
            if highlightedAwards.contains(award) { focusedNewAward = award }
            awardGroup = award.group
            let offset = awardGroup == .rescue ? careerAwards.count : 0
            let index = offeredAwards.firstIndex(of: award) ?? 0
            awardPage = (index + offset) / awardsPerPage
        }
        page(.awards)
    }
    func drawTrolleyAwards() {
        header("Achievements", subtitle: "All levels"); tabs()
        let attempts = ArcadeStore.shared.records.trolley.attempts
        let earned = ArcadeStore.shared.records.careerAchievements(profileID: player.id)
        let local = awardGroup == .rescue ? careerAwards.map {
            ($0.title.capitalized, $0.detail, earned.contains($0))
        } : []
        let awards = offeredAwards
        let progress = awards.map { $0.progress(attempts: attempts, profileID: player.id) }
        let entries = local + zip(awards, progress).map { ($0.0.title, $0.0.detail, $0.1.earned) }
        let annotations = local.map { $0.2 ? "Earned" : "" } + zip(awards, progress).map {
            highlightedAwards.contains($0.0) ? "NEW - \($0.1.label)" : $0.1.label
        }
        let highlighted = Set(awards.enumerated().compactMap { highlightedAwards.contains($0.element) ? local.count + $0.offset : nil })
        link("\(awardGroup.rawValue)  >", CGRect(x: 64, y: 209, width: 300, height: 38)) { [weak self] in
            guard let self else { return }
            let groups = TrolleyAchievementGroup.allCases, index = groups.firstIndex(of: self.awardGroup)!
            self.awardGroup = groups[(index + 1) % groups.count]; self.awardPage = 0; self.needsDisplay = true
        }
        let newAwards = orderedHighlightedAwards
        text("\(entries.filter { $0.2 }.count)/\(entries.count) earned", 384, 216, newAwards.count > 1 ? 210 : 465)
        if newAwards.count > 1 {
            let next = ((focusedNewAward.flatMap { newAwards.firstIndex(of: $0) } ?? -1) + 1) % newAwards.count
            link("Next new \(next + 1)/\(newAwards.count) >", CGRect(x: 612, y: 209, width: 236, height: 38)) { [weak self] in
                self?.showAchievement(newAwards[next])
            }
        }
        drawAwardEntries(entries, annotations: annotations, affinities: local.map { _ in nil } + awards.map(\.philosopherID), highlighted: highlighted)
        drawAwardGroupLinks()
        pageFooter()
        setAccessibilityLabel("\(awardGroup.rawValue) achievements across all levels. Left and right change pages. Up and down or 1 to 4 change collections, and the collection names at the bottom of the page select them directly. "
            + (newAwards.isEmpty ? "" : "New awards from this run are highlighted. \(newAwards.count > 1 ? "Next new moves to the next new award. " : "")")
            + entries.enumerated().map { "\(annotations[$0.offset]): \($0.element.0). \($0.element.1)" }.joined(separator: " "))
    }

    /// The collection row doubles as the keyboard legend, so each entry keeps its
    /// number and becomes its own target. Widths come from the bitmap font so the
    /// row stays centred whatever the collection names are.
    func drawAwardGroupLinks(y: CGFloat = 598) {
        let groups = TrolleyAchievementGroup.allCases
        let labels = groups.enumerated().map { "\($0.offset + 1) \($0.element.rawValue)" }
        let gap: CGFloat = 44, padding: CGFloat = 16
        let widths = labels.map { label in
            font.map { $0.width(of: MacInterfaceRenderer.menuText(label), face: .small, scale: 1) + padding }
                ?? (992 - gap * CGFloat(labels.count - 1)) / CGFloat(labels.count)
        }
        let span = widths.reduce(0, +) + gap * CGFloat(labels.count - 1)
        var x = (64 + (992 - span) / 2).rounded()
        for (index, label) in labels.enumerated() {
            let group = groups[index]
            link(label, CGRect(x: x, y: y, width: widths[index], height: 38),
                 alpha: awardGroup == group ? 1 : 0.55) { [weak self] in
                guard let self else { return }
                self.awardGroup = group; self.awardPage = 0; self.needsDisplay = true
            }
            x += widths[index] + gap
        }
    }

    func drawAwardEntries(_ entries: [(String, String, Bool)], annotations: [String] = [], affinities: [String?] = [], highlighted: Set<Int> = []) {
        let pages = awardPageCount, current = awardPage % pages
        link("More  \(current + 1)/\(pages)  ›", CGRect(x: 873, y: 209, width: 183, height: 38)) { [weak self] in
            self?.awardPage = (current + 1) % pages; self?.needsDisplay = true
        }
        for (index, entry) in entries.dropFirst(current * awardsPerPage).prefix(awardsPerPage).enumerated() {
            let y = CGFloat(264 + index * 86)
            let position = current * awardsPerPage + index
            if highlighted.contains(position) {
                let card = CGRect(x: 64, y: y - 8, width: 992, height: 80)
                GameStyle.fill(card, GameStyle.gold.withAlphaComponent(0.12))
                GameStyle.gold.withAlphaComponent(0.7).setStroke()
                NSBezierPath(rect: card.insetBy(dx: 0.5, dy: 0.5)).stroke()
                GameStyle.fill(CGRect(x: card.minX, y: card.minY, width: 4, height: card.height), GameStyle.gold)
            }
            drawStar(at: CGPoint(x: 86, y: y + 3), earned: entry.2)
            if affinities.indices.contains(position), let id = affinities[position] {
                link(entry.0, CGRect(x: 132, y: y - 6, width: 620, height: 32), alignment: .left, palette: .green) { [weak self] in
                    self?.showAffinity(id, at: CGRect(x: 132, y: y, width: 620, height: 24), forRun: false)
                }
            } else { text(entry.0, 132, y, annotations.isEmpty ? 894 : 620, palette: .green) }
            if annotations.indices.contains(position) { text(annotations[position], 760, y + 3, 270, alignment: .right) }
            let rect = CGRect(x: 132, y: y + 26, width: 894, height: 48)
            if let font { font.menuParagraph(entry.1, in: rect, alignment: .left) }
            else { GamePixelText.draw(entry.1, in: rect) }
        }
    }

    func drawTrolleyDetails(_ conditions: TrolleyConditions) {
        header(level?.title ?? "The Trolley"); tabs()
        let runAssisted = report?.run.assisted ?? assisted
        let history = ArcadeStore.shared.records.trolley, key = conditions.comparisonID(assisted: runAssisted)
        let stored = report?.trolley?.attempt ?? history.attempts.last { $0.comparisonID == key && $0.run.profileID == player.id }
        let attempt = stored.map { $0.assessed(using: history.maximum(conditions: conditions, assisted: runAssisted)) }
        let personal = history.personal(profileID: player.id, comparisonID: key)
        let maximum = attempt?.maximum ?? history.maximum(conditions: conditions, assisted: runAssisted)
        text("This run", 64, 222, 480)
        var rows: [(String, String)] = [
            ("Rescued", attempt.map { String($0.run.saved) } ?? "-"),
            ("Lost", attempt.map { String($0.metrics.lost) } ?? "-"),
            ("Skills used", attempt.map { String($0.run.skillCount) } ?? "-"),
            ("Time", attempt.map { Self.time($0.run.seconds) } ?? "-")]
        if let attempt {
            if attempt.metrics.unreleased > 0 { rows.append((conditions.gameID == "lemmings3" ? "In reserve" : "Still in hatch", String(attempt.metrics.unreleased))) }
            if let telemetry = attempt.run.telemetry {
                if telemetry.nukeCount > 0 { rows.append(("Nukes", String(telemetry.nukeCount))) }
                if telemetry.rewindCount > 0 { rows.append(("Rewinds", String(telemetry.rewindCount))) }
                if telemetry.undoCount > 0 { rows.append(("Undos", String(telemetry.undoCount))) }
            }
        }
        for (index, row) in rows.enumerated() {
            let y = CGFloat(270 + index * 34)
            text(row.0, 64, y, 266)
            text(row.1, 344, y, 248, palette: .green)
        }
        text("This level", 654, 222, 402)
        let clears = history.attempts.filter { $0.comparisonID == key && $0.run.profileID == player.id && $0.run.qualifies }.count
        let levelRows: [(String, String)] = [
            ("Required", String(conditions.rescueRequirement)),
            (maximum.status == .verified ? "Best possible" : maximum.status == .record ? "Best known" : "Maximum", maximum.isRescueTarget ? maximum.value.map(String.init) ?? "Unknown" : "Unknown"),
            ("Personal best", personal.bestSaved.map(String.init) ?? "-"),
            ("Attempts", String(personal.attempts)),
            ("Clears", String(clears))]
        for (index, row) in levelRows.enumerated() {
            let y = CGFloat(270 + index * 34)
            text(row.0, 654, y, 248)
            text(row.1, 910, y, 146, alignment: .right, palette: .green)
        }
        if let attempt {
            affinityLink(attempt.philosophy.primaryID, in: CGRect(x: 64, y: 571, width: 992, height: 36))
        }
        pageFooter()
        setAccessibilityLabel((rows + levelRows).map { $0.0 + ": " + $0.1 }.joined(separator: ". ") + ". Select the play style for an explanation. Escape returns.")
    }
}

@MainActor enum GameStar {
    static func draw(at origin: CGPoint, earned: Bool, size: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = false
        defer { NSGraphicsContext.restoreGraphicsState() }
        let pixels = [".....#.....", "....###....", "....###....", "###########", ".#########.",
                      "..#######..", "..#######..", ".####.####.", ".##.....##."]
        let color = earned ? GameStyle.gold : NSColor(calibratedWhite: 0.62, alpha: 1)
        let silhouette = NSBezierPath()
        for (y, row) in pixels.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "#" {
                let interior = x > 0 && x + 1 < row.count && y > 0 && y + 1 < pixels.count
                    && Array(row)[x - 1] == "#" && Array(row)[x + 1] == "#"
                    && Array(pixels[y - 1])[x] == "#" && Array(pixels[y + 1])[x] == "#"
                if !earned && interior { continue }
                silhouette.appendRect(CGRect(x: origin.x + CGFloat(x) * size, y: origin.y + CGFloat(y) * size, width: size, height: size))
            }
        }
        color.setFill(); silhouette.fill()
    }
}
