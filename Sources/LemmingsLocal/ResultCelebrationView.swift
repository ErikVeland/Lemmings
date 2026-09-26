import AppKit
import NxlvKit

@MainActor extension ArcadeView {
    func finishCelebration() {
        celebrationGeneration = UUID()
        celebrationTask?.cancel(); celebrationTask = nil; rewardChimes.stop()
        revealedStars = 3; stampedStar = nil
    }
    func startCelebration(reduceMotion: Bool? = nil) {
        finishCelebration()
        guard let celebration, celebration.goals.stars > 0,
              !(reduceMotion ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) else { return }
        revealedStars = 0
        let generation = celebrationGeneration
        celebrationTask = Task { @MainActor [weak self] in
            defer {
                if let self, self.celebrationGeneration == generation {
                    self.revealedStars = 3; self.stampedStar = nil
                    self.celebrationTask = nil; self.needsDisplay = true
                }
            }
            for star in 1...celebration.goals.stars {
                do { try await Task.sleep(nanoseconds: 180_000_000) } catch { return }
                guard let self, self.mode == .result, !self.isHidden, self.window != nil else { return }
                self.revealedStars = star; self.stampedStar = star; self.needsDisplay = true
                self.rewardChimes.play(star: star, volume: self.rewardVolume)
                do { try await Task.sleep(nanoseconds: 90_000_000) } catch { return }
                self.stampedStar = nil; self.needsDisplay = true
            }
            self?.celebrationTask = nil
        }
    }
    func paragraph(_ value: String, _ rect: CGRect) {
        if let font { font.menuParagraph(value, in: rect, alignment: .left) }
        else { GamePixelText.draw(value, in: rect) }
    }
    func progressBar(value: Int, goal: Int, in rect: CGRect, earned: Bool = false) {
        GameStyle.fill(rect, GameStyle.muted.withAlphaComponent(0.18))
        let fraction = min(1, max(0, Double(value) / Double(max(1, goal))))
        GameStyle.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height),
                       earned ? GameStyle.gold : GameStyle.accent)
    }
    func drawCelebratedResult(_ report: ArcadeReport) {
        guard let c = celebration else { return }
        let run = report.run, outcome = run.qualifies ? "LEVEL COMPLETE" : "TRY AGAIN"
        title(outcome, x: 80, y: 46, width: 960, height: 40)
        text("\(player.initials)'s attempt - " + run.level.title + (run.assisted ? " - Rewinds used" : ""), 80, 96, 960, alignment: .center, alpha: 0.75)
        title("\(run.saved)/\(run.population)", x: 80, y: 145, width: 270, height: 60)
        text("RESCUED", 80, 208, 270, alignment: .center)
        for index in 0..<3 {
            let stamp = stampedStar == index + 1
            let size: CGFloat = stamp ? 9 : 8
            drawStar(at: CGPoint(x: 466 + CGFloat(index * 166) - (stamp ? 5 : 0), y: 149 - (stamp ? 4 : 0)),
                     earned: index < c.goals.stars && index < revealedStars, size: size)
            if index == 2 && c.goals.stars < 3 && c.goals.fullSaved == nil {
                link("?", CGRect(x: 798 + 3 * size, y: 149 + 2 * size, width: 5 * size, height: 5 * size)) { [weak self] in self?.page(.goals) }
            }
        }
        drawResultLevelCard(c)
        drawResultCareerCard(c)
        resultActions(y: 453)
        let maximum = run.level.conditions.map { ArcadeStore.shared.records.trolley.maximum(conditions: $0, assisted: run.assisted) } ?? TrolleyMaximum()
        let awardText = c.newAwards.map { "New career award: \($0.award.title). \($0.award.detail)" }.joined(separator: " ")
        setAccessibilityLabel("\(player.initials)'s attempt. \(outcome). \(run.level.title). \(rescueSummary(run, maximum: maximum)) \(c.goals.stars) of 3 stars this run. Level best: \(c.bestStars) stars. \(c.nextGoal) \(c.recordMessage). New level awards: \(c.levelAwards.map(\.title).joined(separator: ", ")). \(awardText) Career: \(c.career.stars) stars, plus \(c.addedStars). \(c.nextCareerGoal.map { $0.award.title + ": " + $0.status + ". " + $0.next } ?? "") Local Most Saved: \(c.ranks.first?.label ?? "No record"). Enter: \(primaryResultTitle). R retries. N retries as the next session player. P opens session players. V opens replay. B opens records. A opens achievements. G opens level goals. C opens career progress. D opens details. Escape returns."
            + (report.earnedLevelSkip ? " Earned a level skip." : "")
            + (availableSkips > 0 ? " \(skipTitle). K skips this level." : ""))
    }
    private func drawResultLevelCard(_ c: TrolleyCelebration) {
        let rect = CGRect(x: 80, y: 285, width: 466, height: 116)
        GameStyle.fill(rect, GameStyle.accent.withAlphaComponent(0.065))
        text("THIS LEVEL", 96, 296, 418, height: 22, alpha: 0.85, palette: .green)
        text(c.recordMessage, 96, 323, 418, height: 24)
        let newGoals = c.levelAwards.filter { $0 != .firstClear }
        let names = newGoals.first.map { $0.title.capitalized + (newGoals.count > 1 ? " (+\(newGoals.count - 1))" : "") } ?? ""
        link(names.isEmpty ? "Level goals and bests >" : "NEW: \(names) >",
             CGRect(x: 96, y: 356, width: 418, height: 32), alignment: .left) { [weak self] in self?.page(.goals) }
    }
    private func drawResultCareerCard(_ c: TrolleyCelebration) {
        GameStyle.fill(CGRect(x: 566, y: 285, width: 474, height: 116), GameStyle.gold.withAlphaComponent(0.09))
        let new = c.newAwards
        let earnedSkip = report?.earnedLevelSkip == true
        link("\(report?.run.assisted == true ? "REWIND CAREER" : "CAREER")  \(c.career.stars) STARS" + (c.addedStars > 0 ? "  (+\(c.addedStars))" : "") + " >",
             CGRect(x: 582, y: 292, width: earnedSkip ? 300 : 442, height: 30), alignment: .left, palette: .green) { [weak self] in self?.page(.career) }
        // A skip is earned once, so the result shows it once.
        if earnedSkip {
            link("+1 SKIP", CGRect(x: 894, y: 292, width: 130, height: 30), alignment: .right, palette: .green) { [weak self] in self?.page(.career) }
        }
        if !new.isEmpty {
            let selected = new[featuredAwardIndex % new.count]
            link("NEW: \(selected.award.title) >", CGRect(x: 582, y: 320, width: 442, height: 30), alignment: .left) { [weak self] in
                self?.highlightedAwards = Set(new.map(\.award)); self?.showAchievement(selected.award)
            }
            link("\(new.count) new \(new.count == 1 ? "award" : "awards") >", CGRect(x: 582, y: 360, width: 266, height: 30), alignment: .left) { [weak self] in self?.showNewAwards() }
            if new.count > 1 {
                link("\(featuredAwardIndex % new.count + 1)/\(new.count) Next >", CGRect(x: 861, y: 360, width: 163, height: 30)) { [weak self] in
                    self?.featuredAwardIndex += 1; self?.needsDisplay = true
                }
            }
        } else if let next = c.nextCareerGoal {
            link(next.award.title + " >", CGRect(x: 582, y: 321, width: 442, height: 30), alignment: .left) { [weak self] in self?.showAchievement(next.award) }
            text(next.status, 582, 360, 442, height: 22)
            progressBar(value: next.after.value, goal: next.after.goal, in: CGRect(x: 582, y: 391, width: 442, height: 4))
        } else { text("All career milestones earned!", 582, 338, 442) }
    }
    func drawLevelGoals() {
        header("Level goals", subtitle: level?.title); tabs()
        guard let report, let c = celebration else {
            text("Finish a level to see each goal and your progress.", 80, 270, 960); pageFooter(); return
        }
        text("\(c.goals.stars)/3 this run   -   \(c.bestStars)/3 personal best", 80, 210, 960)
        let previous = report.previousBest
        let run = report.run
        var rows: [(String, String, Bool)] = [
            ("Target met", "Rescue \(run.level.required) and clear the level. Saved \(run.saved).", run.qualifies),
            ("Extra rescue", "Save \(c.goals.extraSaved). \(max(0, c.goals.extraSaved - run.saved)) more to go.", c.goals.stars >= 2),
            ("Three-star rescue", c.goals.fullSaved.map { "Save \($0). \(max(0, $0 - run.saved)) more to go." } ?? "No established target for this level yet.", c.goals.stars == 3),
            ("One more home", previous.map { "Previous best \($0.saved). This run \(run.saved)." } ?? "This run sets your first rescue record.", previous.map { run.saved > $0.saved } ?? false),
            ("Less is more", previous.map { "Match \($0.saved) rescued with fewer than \($0.skillCount) skills." } ?? "Set a first record, then improve its skill count.", report.newSkillBest),
            ("One trick", "Clear with one skill type. This run used \(run.skills.count).", run.qualifies && run.skills.count == 1),
            ("Everyone home", "Rescue all \(run.population) lemmings. Saved \(run.saved).", run.savedAll),
            ("Hands off", run.skillCount == 0 && run.qualifies ? "Cleared without assigning a skill." : "No hands-off clear this run. This goal may not be possible here.", run.qualifies && run.skillCount == 0)
        ]
        if !run.savedAll && c.goals.fullSaved != run.population { rows.removeAll { $0.0 == "Everyone home" } }
        let handsOffKnown = ArcadeStore.shared.records.trolley.attempts.contains {
            $0.run.level.boardID == run.level.boardID && $0.run.qualifies && $0.run.skillCount == 0
        }
        if !handsOffKnown { rows.removeAll { $0.0 == "Hands off" } }
        for (index, row) in rows.enumerated() {
            let y = CGFloat(252 + index * 44)
            drawStar(at: CGPoint(x: 82, y: y + 3), earned: row.2)
            let matches: [String: ArcadeLevelAchievement] = ["Target met": .firstClear, "One more home": .betterRescue,
                "Less is more": .fewerSkills, "One trick": .oneSkill, "Everyone home": .allHome, "Hands off": .noSkills]
            let isNew = matches[row.0].map { report.earned.contains($0) } ?? false
            text(row.0 + (isNew ? " - NEW AWARD" : row.2 ? " - MET" : ""), 130, y, 860, height: 24)
            text(row.1, 130, y + 23, 860, height: 22, alpha: 0.7)
        }
        pageFooter()
        setAccessibilityLabel("This level. " + rows.map { $0.0 + ": " + ($0.2 ? "Met. " : "Not met. ") + $0.1 }.joined(separator: " "))
    }
    func drawCareerProgress() {
        header("Career progress", subtitle: "Across all recorded levels"); tabs()
        let history = ArcadeStore.shared.records.trolley
        let score = celebration?.career ?? TrolleyCareerScore(profileID: player.id, attempts: history.attempts, assisted: assisted)
        let deltas = celebration?.awards ?? TrolleyAchievement.allCases.filter(\.isOffered).map { award in
            let progress = award.progress(attempts: history.attempts, profileID: player.id)
            return TrolleyAwardDelta(award: award, before: progress, after: progress, isNew: false)
        }
        text("\(score.stars) stars   \(score.clearedLevels) cleared   \(score.threeStarLevels) three-star levels", 80, 212, assisted ? 960 : 640)
        if !assisted { drawSkipBalance(ArcadeStore.shared.records.levelSkips(profileID: player.id)) }
        let milestones = deltas.filter { $0.after.goal > 1 }
        let pages = max(1, (milestones.count + 3) / 4)
        for (index, delta) in milestones.dropFirst((careerPage % pages) * 4).prefix(4).enumerated() {
            let y = CGFloat(264 + index * 77)
            link(delta.award.title + " >", CGRect(x: 80, y: y, width: 650, height: 30), alignment: .left) { [weak self] in self?.showAchievement(delta.award) }
            text(delta.status, 766, y + 7, 274, alignment: .right, height: 24)
            text(delta.after.earned ? delta.award.detail : delta.next, 80, y + 33, 960, height: 24, alpha: 0.75)
            progressBar(value: delta.after.value, goal: delta.after.goal, in: CGRect(x: 80, y: y + 61, width: 960, height: 5), earned: delta.after.earned)
        }
        link("More \(careerPage % pages + 1)/\(pages) >", CGRect(x: 786, y: 574, width: 254, height: 34)) { [weak self] in self?.careerPage += 1; self?.needsDisplay = true }
        link("Career leaderboard >", CGRect(x: 80, y: 574, width: 590, height: 34), alignment: .left) { [weak self] in self?.boardScope = .career; self?.page(.records) }
        pageFooter()
        setAccessibilityLabel("Career progress. \(score.stars) stars, plus \(celebration?.addedStars ?? 0) this run. \(score.clearedLevels) distinct levels cleared. \(score.threeStarLevels) three-star levels. " + (assisted ? "" : { let skips = ArcadeStore.shared.records.levelSkips(profileID: player.id)
            return "\(skips.available) level skips. \(skips.threeStarLevelsToNext) more three-star levels for the next. " }())
            + milestones.map { $0.award.title + ": " + $0.status + ". " + $0.next }.joined(separator: " "))
    }
    /// Skips to spend, then filled and outlined pips for three-star levels toward the next one.
    private func drawSkipBalance(_ skips: LevelSkipBalance) {
        text("SKIPS \(skips.available)", 740, 212, 180, alignment: .right, palette: .green)
        let done = LevelSkipBalance.threeStarLevelsPerSkip - skips.threeStarLevelsToNext
        for index in 0..<LevelSkipBalance.threeStarLevelsPerSkip {
            let pip = CGRect(x: 940 + CGFloat(index) * 34, y: 216, width: 20, height: 20)
            if index < done { GameStyle.fill(pip, GameStyle.gold) }
            else {
                GameStyle.gold.setStroke()
                let outline = NSBezierPath(rect: pip.insetBy(dx: 1, dy: 1)); outline.lineWidth = 2; outline.stroke()
            }
        }
    }
    func boardScopeLinks() {
        // This row replaces the generic game subtitle on leaderboard pages.
        GameStyle.fill(CGRect(x: 70, y: 100, width: 980, height: 34), .black)
        for (index, item) in [(BoardScope.level, "This level"), (.career, "All levels"), (.worldwide, "Worldwide")].enumerated() {
            link(item.1 + (boardScope == item.0 ? " *" : " >"), CGRect(x: 170 + index * 260, y: 99, width: 250, height: 34), palette: boardScope == item.0 ? .green : .blue) { [weak self] in
                guard let self else { return }
                self.boardScope = item.0
                if item.0 == .worldwide { self.openWorldwideBoard() } else { self.needsDisplay = true }
            }
        }
    }
    func drawCareerBoard() {
        header("Career leaderboard"); tabs(); boardScopeLinks(); rewindFilter()
        let history = ArcadeStore.shared.records.trolley
        let attempts = history.attempts.map { a in a.assessed(using: history.maximum(conditions: a.run.level.conditions!, assisted: a.run.assisted)) }
        let rows = TrolleyCareerScore.rank(attempts: attempts, assisted: assisted)
        text("Best stars per level, counted once", 80, 220, 680)
        text("PLAYER", 174, 278, 260); text("STARS", 524, 278, 140)
        text("CLEARED", 724, 278, 160); text("3-STAR", 924, 278, 120)
        for (index, score) in rows.prefix(5).enumerated() {
            let y = CGFloat(321 + index * 47)
            GameStyle.fill(CGRect(x: 80, y: y - 5, width: 960, height: 44), score.profileID == player.id ? GameStyle.gold.withAlphaComponent(0.12) : .clear)
            let row = CGRect(x: 80, y: y - 5, width: 960, height: 44)
            rowText("\(index + 1)", x: 96, width: 60, row: row)
            rowText(ArcadeStore.shared.records.profile(score.profileID)?.initials ?? "LEM", x: 174, width: 260, row: row)
            rowText("\(score.stars)", x: 524, width: 140, row: row); rowText("\(score.clearedLevels)", x: 724, width: 160, row: row); rowText("\(score.threeStarLevels)", x: 924, width: 120, row: row)
        }
        if rows.isEmpty { text("No completed attempts in this category yet.", 80, 340, 960) }
        text("Local players on this Mac. Worldwide uses Game Center.", 80, 578, 960)
        pageFooter()
        setAccessibilityLabel("Local career leaderboard. Rewinds \(assisted ? "used" : "unused"). Best stars per distinct level. " + rows.enumerated().map { "Rank \($0.offset + 1), \(ArcadeStore.shared.records.profile($0.element.profileID)?.initials ?? "LEM"), \($0.element.stars) stars." }.joined(separator: " "))
    }
}
