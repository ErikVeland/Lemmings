#if os(tvOS)
import AVFoundation
import GameController
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit
import UIKit

@MainActor final class TVLibraryViewController: UIViewController {
    private enum Route { case home, games, ranks, levels, briefing, deck, skills, camera, targets, transport, settings, audio, players, player, roster, help, results, confirmRetry, confirmEnd, error }
    private let sources: [TVLibrarySource]
    private let menu = TVMenuView()
    private let playfield = TVPlayfieldView()
    private let input = TVInputAdapter()
    private let audio = TVAudio()
    private var local: TVLocalState
    private var route = Route.home
    private var previousRoute = Route.home
    private var context = UUID()
    private var source: TVLibrarySource?
    private var levels: [MobileLevelSummary] = []
    private var selectedRank = ""
    private var ranks: [String] { levels.reduce(into: []) { if !$0.contains($1.rank) { $0.append($1.rank) } } }
    private var selectedLevel = 0
    private var pageOffset = 0
    private var loader: MobileMenuPreviewLoader?
    private var game: TVGameExperience?
    private var seat: MobileHotSeat?
    private var roster: MobileHotSeatRoster?
    private var rosterOffset = 0
    private var editingPlayerID = MobileProfiles.defaultID
    private var checkpoint: MobileCheckpointEnvelope?
    private var preview: CGImage?
    private var preparation: Task<Void, Never>?
    private var generation = UUID()
    private var busy = false
    private var link: CADisplayLink?
    private var errorMessage = ""
    private var cameraAdjustment = false
    private var lastSaveTime = 0.0
    private var resultHandledRunID: UUID?
    private let checkpoints: MobileCheckpointStore
    private var appObservers: [NSObjectProtocol] = []

    init(sources: [TVLibrarySource]) {
        self.sources = sources
        local = UserDefaults.standard.data(forKey: "tv.localState").flatMap { try? JSONDecoder().decode(TVLocalState.self, from: $0) } ?? .init()
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UltimateLemmings/TV/Checkpoints/current.json")
        checkpoints = MobileCheckpointStore(url: root)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }
    override var preferredFocusEnvironments: [any UIFocusEnvironment] { menu.isHidden ? [playfield] : [menu] }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        view.addSubview(playfield); view.addSubview(menu)
        playfield.isHidden = true
        menu.onAction = { [weak self] in self?.handle($0) }
        input.preferences = local.preferences.validated
        audio.apply(local.preferences)
        input.onMenuNeutral = { [weak self] in self?.menu.armActivation() }
        input.onAim = { [weak self] dx, dy in
            guard let self, let game = self.game, self.menu.isHidden else { return }
            if self.cameraAdjustment { game.pan(dx: dx, dy: dy) }
            else { game.aim(dx: dx, dy: dy) }
        }
        input.onPan = { [weak self] dx, dy in self?.game?.pan(dx: dx, dy: dy) }
        input.onAction = { [weak self] in self?.controllerAction($0) }
        input.onDisconnect = { [weak self] in self?.interrupt() }
        playfield.onAssign = { [weak self] in
            guard let self, let game = self.game else { return }
            if game.assign() { self.audio.update(game) }
            self.playfield.refresh()
        }
        playfield.onCycle = { [weak self] in self?.game?.cycleTarget($0); self?.playfield.refresh() }
        playfield.onPause = { [weak self] in self?.showDeck() }
        playfield.onRenderFailure = { [weak self] message in
            self?.fail(NSError(domain: "TVPlayfield", code: 1, userInfo: [NSLocalizedDescriptionKey: message]), back: .deck)
        }
        audio.onInterruption = { [weak self] began in
            guard let self else { return }
            if began { self.game?.suspend(interruption: true); self.interrupt() }
            else { self.game?.interruptionEnded() }
        }
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            appObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.game?.suspend(inactive: true); self?.interrupt() }
            })
        }
        appObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.game?.becameActive(); self?.input.reset() }
        })
        link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link?.preferredFramesPerSecond = 60; link?.add(to: .main, forMode: .common)
        show(.home)
        Task { [weak self] in
            guard let self else { return }
            do { self.checkpoint = try await self.checkpoints.load(); if self.game == nil { self.show(self.route) } }
            catch { self.fail(error, back: .home) }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Reserve breathing room for focus outlines and TVs with cropped edges.
        let safe = view.bounds.inset(by: UIEdgeInsets(top: max(48, view.safeAreaInsets.top), left: max(72, view.safeAreaInsets.left),
            bottom: max(48, view.safeAreaInsets.bottom), right: max(72, view.safeAreaInsets.right)))
        menu.frame = safe; playfield.frame = safe
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if menu.isHidden {
            // Game Controller polling is the only gameplay commit path.
            return
        }
        if route != .home, presses.contains(where: { $0.type == .menu }) { back(); return }
        if GCController.controllers().isEmpty, presses.contains(where: { $0.type == .select }) { menu.armActivation() }
        super.pressesBegan(presses, with: event)
    }

    @objc private func frame(_ link: CADisplayLink) {
        input.poll(at: link.timestamp, context: context, menu: !menu.isHidden)
        guard let game else { return }
        if game.advance(at: link.timestamp) { audio.update(game) }
        if game.play.phase == .completed, resultHandledRunID != game.runID { completed(); return }
        if menu.isHidden { playfield.refresh() }
        if game.canInteract, !busy, menu.isHidden, link.timestamp - lastSaveTime > 15 {
            lastSaveTime = link.timestamp; saveRun()
        }
    }

    private func show(_ destination: Route) {
        route = destination; context = UUID(); input.reset()
        cameraAdjustment = false; playfield.cameraAdjustment = false
        menu.isHidden = false; playfield.isHidden = true
        menu.textScale = local.preferences.textScale
        menu.preferredActionID = nil
        var page = GameFrontEnd.Page(title: L10n.text("Ultimate Lemmings"))
        let back = GameFrontEnd.Action("back", L10n.text("Back"))
        let name = game.map { player($0.owner).name } ?? local.profiles.active.name
        switch destination {
        case .home:
            page.home = true
            page.subtitle = local.profiles.active.name
            page.rows = [.init("hotseat", L10n.text("Hot Seat")), .init("players", L10n.text("Players")), .init("settings", L10n.text("Settings"))]
            if let checkpoint {
                page.rows.append(.init("games", L10n.text("Play")))
                page.footer = [.init("restore", L10n.text("Resume level - ") + player(checkpoint.owner ?? MobileProfiles.defaultID).name, primary: true)]
            } else {
                page.footer = [.init("games", L10n.text("Play"), primary: true)]
            }
        case .games:
            page.title = L10n.text("Choose a game")
            page.rows = ["classic", "lemmings2", "lemmings3"].map { id in
                .init("source." + id, id == "classic" ? L10n.text("Lemmings") : id == "lemmings2" ? L10n.text("Lemmings 2") : L10n.text("Lemmings 3"),
                    enabled: sources.contains(where: { $0.id == id }), primary: id == "classic")
            }
            page.subtitle = sources.isEmpty ? L10n.text("Game data unavailable") : ""
            page.footer = [back]
        case .ranks:
            page.title = source?.title ?? L10n.text("Levels")
            page.rows = ranks.enumerated().dropFirst(pageOffset).prefix(4).map { .init("rank.\($0.offset)", $0.element) }
            page.footer = [back, .init("previous", "<", enabled: pageOffset > 0), .init("more", ">", enabled: pageOffset + 4 < ranks.count)]
        case .levels:
            page.title = selectedRank
            let browse = levels.filter { $0.rank == selectedRank }
            let progress = local.completed[local.progressKey(source: source?.id ?? "", owner: local.profiles.activeID, scope: seat?.scope)] ?? []
            page.rows = browse.dropFirst(pageOffset).prefix(4).map {
                .init("level.\($0.index)", "\($0.number) - \($0.title)", selected: progress.contains($0.index))
            }
            page.subtitle = "\(pageOffset + 1)-\(min(pageOffset + 4, browse.count)) / \(browse.count)"
            page.footer = [back, .init("previous", "<", enabled: pageOffset > 0), .init("more", ">", enabled: pageOffset + 4 < browse.count)]
        case .briefing:
            guard let game else { return }
            page.title = game.content.summary.title; page.subtitle = seat == nil ? game.content.summary.rank : name
            page.preview = true
            let snapshot = game.session.snapshot
            page.details = ["\(snapshot.total) LEMMINGS  /  SAVE \(snapshot.required)", snapshot.remainingSeconds.map { "\($0 / 60) MINUTES" } ?? ""]
            page.rows = [.init("ready", game.awaitsFirstStart ? (seat == nil ? L10n.text("Start") : L10n.text("Ready")) : L10n.text("Resume"), primary: true, portrait: player(game.owner).portrait)]
            page.footer = [back]
        case .deck:
            page.title = L10n.text("Paused"); page.subtitle = name
            page.rows = [.init("skills", L10n.text("Skills")), .init("targets", L10n.text("Lemmings")), .init("camera", L10n.text("Camera")), .init("transport", L10n.text("Time and actions")), .init("help", L10n.text("Controls"))]
            page.footer = [.init("library", L10n.text("Library")), .init("retryConfirm", L10n.text("Retry")), .init("resume", L10n.text("Resume"), primary: true)]
        case .skills:
            guard let game else { return }
            menu.preferredActionID = "skill.\(game.selectedControl)"
            page.title = game.capabilities.carriedTools ? L10n.text("Actions and tools") : L10n.text("Skills")
            page.rows = game.session.snapshot.skills.enumerated().dropFirst(pageOffset).prefix(4).map { index, skill in
                .init("skill.\(index)", "\(skill.name)  \(skill.isUnlimited ? "*" : String(skill.count))", enabled: skill.count > 0 || skill.isUnlimited, selected: index == game.selectedControl)
            }
            page.footer = [back, .init("previousSkills", "<", enabled: pageOffset > 0), .init("moreSkills", ">", enabled: pageOffset + 4 < game.session.snapshot.skills.count)]
        case .camera:
            page.title = L10n.text("Camera")
            menu.preferredActionID = "zoom.\(game?.cameraMode.rawValue ?? 1)"
            page.rows = [.init("zoom.0", L10n.text("Overview"), selected: game?.cameraMode == .overview), .init("zoom.1", L10n.text("Play"), selected: game?.cameraMode == .play),
                .init("zoom.2", L10n.text("Precision"), selected: game?.cameraMode == .precision), .init("entrance", L10n.text("Entrance")), .init("goal", L10n.text("Exit"))]
            page.footer = [back, .init("pan", L10n.text("Move camera"), primary: true)]
        case .targets:
            page.title = L10n.text("Lemmings")
            page.rows = [.init("target.previous", L10n.text("Previous eligible lemming")), .init("target.next", L10n.text("Next eligible lemming"), primary: true), .init("target.last", L10n.text("Last assignment"), enabled: game?.lastAssignment != nil)]
            page.footer = [back]
        case .transport:
            guard let game else { return }
            page.title = L10n.text("Time and actions")
            page.rows = [.init("step", L10n.text("Step forward")), .init("stepBack", L10n.text("Step back"), enabled: game.capabilities.rewind), .init("rewind", L10n.text("Rewind"), enabled: game.capabilities.rewind),
                .init("speed", L10n.text("Speed \(Int(game.speed))X")), .init("endConfirm", game.session.snapshot.isEndingRun ? L10n.text("Undo nuke") : game.capabilities.nuke ? L10n.text("Nuke") : L10n.text("End attempt"))]
            page.footer = [back]
            if game.capabilities.releaseRate { page.footer += [.init("rateDown", L10n.text("Rate -")), .init("rateUp", L10n.text("Rate +"))] }
        case .settings:
            page.title = L10n.text("Settings")
            page.rows = [.init("planning", L10n.text("Pause on skill change"), selected: local.preferences.planningOnSkillChange), .init("sensitivity", L10n.text("Aim \(String(format: "%.1f", local.preferences.aimSensitivity))")),
                .init("text", L10n.text("Large menu text"), selected: local.preferences.textScale > 1), .init("swap", L10n.text("Swap sticks"), selected: local.preferences.swapSticks), .init("audio", L10n.text("Audio"))]
            page.footer = [back]
        case .audio:
            page.title = L10n.text("Audio")
            page.rows = [.init("music", L10n.text("Music"), selected: local.preferences.musicEnabled), .init("effects", L10n.text("Sound effects"), selected: local.preferences.effectsEnabled)]
            page.footer = [back]
        case .players:
            page.title = L10n.text("Players")
            page.rows = local.profiles.players.dropFirst(rosterOffset).prefix(4).map { .init("player." + $0.id, $0.name, selected: $0.id == local.profiles.activeID, portrait: $0.portrait) }
            page.footer = [back, .init("playerMore", ">", enabled: local.profiles.players.count > 4), .init("addPlayer", L10n.text("Add player"), enabled: local.profiles.players.count < MobileProfiles.maximum, primary: true)]
        case .player:
            let profile = player(editingPlayerID)
            page.title = profile.name
            page.rows = [.init("renamePlayer", L10n.text("Name")), .init("portrait", L10n.text("Portrait"), portrait: profile.portrait), .init("usePlayer", L10n.text("Choose player"), primary: true)]
            page.footer = [back]
        case .roster:
            page.title = L10n.text("Hot Seat")
            page.rows = local.profiles.players.dropFirst(rosterOffset).prefix(4).map { .init("roster." + $0.id, $0.name, enabled: $0.id != roster?.host, selected: roster?.contains($0.id) ?? false, portrait: $0.portrait) }
            page.footer = [back, .init("rosterMore", ">", enabled: local.profiles.players.count > 4), .init("startSeat", L10n.text("Continue"), enabled: roster?.canStart ?? false, primary: true)]
        case .help:
            page.title = L10n.text("Controls")
            page.details = [L10n.text("LEFT STICK: AIM  /  RIGHT STICK: CAMERA"), L10n.text("SHOULDERS: SKILLS  /  D-PAD: TARGETS"), L10n.text("PRIMARY BUTTON: ASSIGN  /  MENU: PAUSE"), L10n.text("REMOTE: MOVE, CLICK TO ASSIGN"), L10n.text("PLAY/PAUSE: PAUSE  /  BACK: CONTROLS"), L10n.text(L10n.text("SKILL CHANGES CAN PAUSE FOR PLANNING")), L10n.text("CAMERA, STEP AND SPEED: PAUSED CONTROLS")]
            page.footer = [back]
        case .results:
            guard let game else { return }
            page.title = game.session.snapshot.didWin ? L10n.text("Level complete") : L10n.text("Try again")
            page.subtitle = name
            page.preview = true
            page.details = ["\(game.session.snapshot.saved) / \(game.session.snapshot.total) RESCUED"]
            if let seat {
                page.rows = seat.choices(didWin: game.session.snapshot.didWin).map { choice in
                    .init((choice.kind == .next ? "next." : "retry.") + choice.player,
                        (choice.kind == .next ? L10n.text("Next - ") : L10n.text("Retry - ")) + player(choice.player).name,
                        enabled: choice.kind != .next || selectedLevel + 1 < levels.count, primary: choice.primary, portrait: player(choice.player).portrait)
                }
            } else {
                page.rows = [.init("next", L10n.text("Next"), enabled: game.session.snapshot.didWin && selectedLevel + 1 < levels.count, primary: game.session.snapshot.didWin && selectedLevel + 1 < levels.count), .init("retry", L10n.text("Retry"), primary: !game.session.snapshot.didWin || selectedLevel + 1 == levels.count)]
            }
            if !page.rows.contains(where: { $0.primary && $0.enabled }), let first = page.rows.firstIndex(where: \.enabled) {
                for index in page.rows.indices { page.rows[index].primary = index == first }
            }
            page.rows = page.rows.filter { !$0.primary } + page.rows.filter(\.primary)
            page.footer = [.init("library", L10n.text("Library"))]
        case .confirmRetry, .confirmEnd:
            page.title = destination == .confirmRetry ? L10n.text("Retry level?") : L10n.text("End attempt?")
            page.footer = [.init("cancel", L10n.text("Cancel"), primary: true), .init(destination == .confirmRetry ? "retry" : "end", destination == .confirmRetry ? L10n.text("Retry") : L10n.text("End attempt"))]
        case .error:
            page.title = L10n.text("Unable to continue"); page.details = wrapped(errorMessage, columns: 44)
            page.footer = [back]
        }
        if busy { page.subtitle = L10n.text("Loading") }
        menu.preview = preview; menu.page = page
        setNeedsFocusUpdate(); updateFocusIfNeeded()
    }

    private func handle(_ id: String) {
        if busy {
            guard preparation != nil else { return }
            if id == "back" { back(); return }
            cancelPreparation()
        }
        if id.hasPrefix("source."), let chosen = sources.first(where: { $0.id == String(id.dropFirst(7)) }) { open(chosen); return }
        if id.hasPrefix("rank."), let index = Int(id.dropFirst(5)), ranks.indices.contains(index) { selectedRank = ranks[index]; pageOffset = 0; show(.levels); return }
        if id.hasPrefix("level."), let index = Int(id.dropFirst(6)) { prepare(index); return }
        if id.hasPrefix("skill."), let index = Int(id.dropFirst(6)) { game?.selectSkill(index); showPlay(); return }
        if id.hasPrefix("zoom."), let index = Int(id.dropFirst(5)), let mode = TVCameraMode(rawValue: index) { game?.setCamera(mode); show(.camera); return }
        if id.hasPrefix("player.") { editingPlayerID = String(id.dropFirst(7)); show(.player); return }
        if id.hasPrefix("roster.") { roster?.toggle(String(id.dropFirst(7))); show(.roster); return }
        if id.hasPrefix("retry.") || id.hasPrefix("next.") {
            let next = id.hasPrefix("next."); let owner = String(id.dropFirst(next ? 5 : 6))
            prepare(selectedLevel + (next ? 1 : 0), nextOwner: owner); return
        }
        switch id {
        case "back", "cancel": back()
        case "games": seat = nil; show(.games)
        case "hotseat":
            if local.profiles.players.count == 1 { addPlayer() }
            roster = .init(host: local.profiles.activeID); rosterOffset = 0; show(.roster)
        case "startSeat":
            guard let roster, let newSeat = MobileHotSeat(host: roster.host, players: roster.players) else { return }
            seat = newSeat; local.seats[newSeat.scope] = newSeat; persist(); show(.games)
        case "players": rosterOffset = 0; show(.players)
        case "addPlayer": addPlayer(); show(.player)
        case "usePlayer": local.profiles.select(editingPlayerID); persist(); show(.players)
        case "renamePlayer": renamePlayer()
        case "portrait": local.profiles.setPortrait(editingPlayerID, to: (player(editingPlayerID).portrait + 1) % 8); persist(); show(.player)
        case "playerMore", "rosterMore": rosterOffset = rosterOffset == 0 ? 4 : 0; show(route)
        case "settings": show(.settings)
        case "audio": show(.audio)
        case "music": local.preferences.musicEnabled.toggle(); audio.apply(local.preferences); persist(); show(.audio)
        case "effects": local.preferences.effectsEnabled.toggle(); audio.apply(local.preferences); persist(); show(.audio)
        case "planning": local.preferences.planningOnSkillChange.toggle(); settingsChanged()
        case "sensitivity": local.preferences.aimSensitivity = local.preferences.aimSensitivity >= 2 ? 0.5 : local.preferences.aimSensitivity + 0.5; settingsChanged()
        case "text": local.preferences.textScale = local.preferences.textScale == 1 ? 1.25 : 1; settingsChanged()
        case "swap": local.preferences.swapSticks.toggle(); settingsChanged()
        case "previous": pageOffset = max(0, pageOffset - 4); show(route)
        case "more": pageOffset += 4; show(route)
        case "restore": restore()
        case "ready", "resume": input.claimMenuDevice(); if game?.resume() == true { if let game { audio.start(game) }; showPlay() }
        case "skills": pageOffset = (game?.selectedControl ?? 0) / 4 * 4; show(.skills)
        case "previousSkills": pageOffset = max(0, pageOffset - 4); show(.skills)
        case "moreSkills": pageOffset += 4; show(.skills)
        case "camera": show(.camera)
        case "targets": show(.targets)
        case "transport": show(.transport)
        case "help": show(.help)
        case "pan": game?.pause(); showPlay(); cameraAdjustment = true; playfield.cameraAdjustment = true
        case "entrance": game?.centre(entrance: true); show(.camera)
        case "goal": game?.centre(entrance: false); show(.camera)
        case "target.previous": game?.cycleTarget(-1); showPlay()
        case "target.next": game?.cycleTarget(1); showPlay()
        case "target.last": game?.focusLast(); showPlay()
        case "step": game?.step(); if game?.play.phase == .completed { completed() } else { show(.transport) }
        case "stepBack": game?.step(backward: true); show(.transport)
        case "rewind": game?.rewind(); show(.transport)
        case "speed": if game?.speed == 10 { game?.clearSpeed() } else { game?.changeSpeed(1) }; show(.transport)
        case "rateDown": game?.rate(-1); show(.transport)
        case "rateUp": game?.rate(1); show(.transport)
        case "retryConfirm": show(.confirmRetry)
        case "retry": prepare(selectedLevel)
        case "next": prepare(selectedLevel + 1)
        case "endConfirm":
            if game?.session.snapshot.isEndingRun == true { game?.endRun(); show(.transport) }
            else { show(.confirmEnd) }
        case "end": game?.endRun(); if game?.resume() == true { if let game { audio.start(game) }; showPlay() }
        case "library": saveAndLeave()
        default: show(route)
        }
    }

    private func controllerAction(_ action: ControllerBindings.Action) {
        guard menu.isHidden, let game else { return }
        if cameraAdjustment {
            switch action { case .assign, .cancel, .pause: showDeck(); default: break }
            return
        }
        switch action {
        case .djShuffle: break // The diagnostic shell has no DJ. The shared frontend handles this command.
        case .assign: if game.assign() { audio.update(game) }
        case .repeatAssignment: if game.assign(repeatLast: true) { audio.update(game) }
        case .cycle(let delta): game.cycleSkill(delta); if game.play.isPaused { audio.pause() }
        case .focusUnassigned(let delta): game.cycleTarget(delta)
        case .focusLast: game.focusLast()
        case .centre(let entrance): game.centre(entrance: entrance)
        case .rate(let delta): game.rate(delta)
        case .step(let direction): game.step(backward: direction < 0); audio.pause()
        case .rewind: game.rewind(); audio.pause()
        case .boost(let held): game.boost(held, at: ProcessInfo.processInfo.systemUptime)
        case .speedStep(let delta): game.changeSpeed(delta)
        case .speedReset: game.clearSpeed()
        case .pause:
            if game.play.phase == .planning { if game.resume() { audio.start(game) } }
            else { showDeck() }
        case .cancel: if game.speed > 1 { game.clearSpeed() } else { showDeck() }
        case .help, .hints: game.pause(); audio.pause(); show(.help)
        case .settings: game.pause(); audio.pause(); show(.settings)
        case .retry: game.pause(); audio.pause(); show(.confirmRetry)
        case .endRun:
            if game.session.snapshot.isEndingRun { game.endRun() }
            else { game.pause(); audio.pause(); show(.confirmEnd) }
        }
        if game.play.phase == .completed { completed() }
    }

    private func showPlay() {
        guard let game else { return }
        cameraAdjustment = false; playfield.cameraAdjustment = false
        route = .deck; context = UUID(); input.reset()
        menu.isHidden = true; playfield.isHidden = false
        playfield.experience = game; playfield.ownerName = player(game.owner).name; playfield.ownerPortrait = player(game.owner).portrait
        playfield.setNeedsLayout(); playfield.layoutIfNeeded(); playfield.refresh(force: true)
        becomeFirstResponder(); setNeedsFocusUpdate()
    }
    private func showDeck() { game?.pause(); audio.pause(); show(.deck); saveRun() }
    private func interrupt() {
        guard game != nil else { audio.pause(); return }
        input.reset(); audio.pause(); game?.suspend(); show(.deck); saveRun()
    }

    private func open(_ chosen: TVLibrarySource) {
        cancelPreparation(); source = chosen; loader = .init(makeLibrary: chosen.makeLibrary)
        busy = true; show(.games)
        let token = generation
        preparation = Task { [weak self] in
            do {
                let summaries = try await TVLibraryCatalogue(source: chosen).levels()
                guard let self, token == self.generation, !Task.isCancelled else { return }
                self.preparation = nil; self.levels = summaries; self.busy = false; self.pageOffset = 0; self.show(.ranks)
            } catch { guard let self, token == self.generation, !Task.isCancelled else { return }; self.preparation = nil; self.busy = false; self.fail(error, back: .games) }
        }
    }
    private func prepare(_ index: Int, restoring saved: MobileCheckpointEnvelope? = nil, nextOwner: String? = nil) {
        guard let loader, levels.indices.contains(index) else { return }
        cancelPreparation(); busy = true; show(route)
        let token = generation
        let owner = nextOwner ?? seat?.turn ?? local.profiles.activeID
        let scope = seat?.scope
        let preferences = local.preferences
        preparation = Task { [weak self] in
            do {
                let prepared = try await loader.prepare(index)
                guard let self, token == self.generation, !Task.isCancelled else { return }
                let nextGame = try TVGameExperience(content: prepared.content, owner: owner, scope: scope, preferences: preferences, checkpoint: saved)
                let preview = try self.levelPreview(nextGame)
                let draft = try nextGame.prepareCheckpoint()
                let value = try await Task.detached(priority: .utility) { try draft.encode() }.value
                guard token == self.generation, !Task.isCancelled else { return }
                let previousGame = self.game
                // Once storage commits, Back cannot abandon a partially replaced turn.
                self.preparation = nil
                previousGame?.pause(); self.audio.pause()
                self.local.checkpointSources[value.runID.uuidString] = self.source?.id
                self.persist()
                try await self.checkpoints.save(value)
                if let previousGame, previousGame.runID != nextGame.runID {
                    try await self.checkpoints.retire(runID: previousGame.runID)
                    self.local.checkpointSources.removeValue(forKey: previousGame.runID.uuidString)
                }
                if let nextOwner { self.seat?.pass(to: nextOwner) }
                if let seat = self.seat { self.local.seats[seat.scope] = seat }
                self.local.activeSeatScope = scope; self.persist()
                self.game?.pause(); self.audio.stop(); self.input.releaseOwner()
                self.preparation = nil; self.game = nextGame; self.selectedLevel = index; self.busy = false
                self.selectedRank = nextGame.content.summary.rank
                self.checkpoint = value; self.preview = preview
                if UIApplication.shared.applicationState != .active { nextGame.suspend(inactive: true) }
                self.show(.briefing)
            } catch { guard let self, token == self.generation, !Task.isCancelled else { return }; self.preparation = nil; self.busy = false; self.fail(error, back: .levels) }
        }
    }
    private func restore() {
        guard let checkpoint else { return }
        guard let key = local.checkpointSources[checkpoint.runID.uuidString], let source = sources.first(where: { $0.id == key }) else {
            fail(NSError(domain: "TVLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.text("The saved game's library is unavailable.")]), back: .home); return
        }
        cancelPreparation(); busy = true; show(.home)
        let token = generation
        preparation = Task { [weak self] in
            do {
                let levels = try await TVLibraryCatalogue(source: source).levels()
                guard let self, token == self.generation, !Task.isCancelled else { return }
                if let scope = checkpoint.scope {
                    guard let seat = self.local.seats[scope], seat.players.contains(checkpoint.owner ?? "") else { throw MobileCheckpointError.invalid }
                    self.seat = seat
                } else { self.seat = nil; self.local.profiles.select(checkpoint.owner ?? MobileProfiles.defaultID) }
                self.source = source; self.loader = .init(makeLibrary: source.makeLibrary); self.levels = levels
                self.busy = false; self.prepare(checkpoint.levelIndex, restoring: checkpoint, nextOwner: checkpoint.owner)
            } catch { guard let self, token == self.generation, !Task.isCancelled else { return }; self.preparation = nil; self.busy = false; self.fail(error, back: .home) }
        }
    }
    private func completed() {
        guard let game, let source, resultHandledRunID != game.runID else { return }
        resultHandledRunID = game.runID
        audio.pause(); input.reset()
        preview = try? levelPreview(game)
        if game.session.snapshot.didWin {
            let key = local.progressKey(source: source.id, owner: game.owner, scope: game.scope)
            local.completed[key, default: []].insert(selectedLevel); persist()
        }
        show(.results)
        // Retire before a result can create another attempt.
        busy = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.checkpoints.retire(runID: game.runID)
                if self.checkpoint?.runID == game.runID { self.checkpoint = nil }
                self.local.checkpointSources.removeValue(forKey: game.runID.uuidString); self.persist()
                self.busy = false; if self.route == .results { self.show(.results) }
            } catch { self.preparation = nil; self.busy = false; self.fail(error, back: .results) }
        }
    }
    private func saveRun() {
        guard let game, game.play.phase != .completed, let source else { return }
        do {
            let draft = try game.prepareCheckpoint()
            local.checkpointSources[draft.metadata.runID.uuidString] = source.id; persist()
            Task { [weak self] in
                guard let self else { return }
                do {
                    let value = try await Task.detached(priority: .utility) { try draft.encode() }.value
                    try await self.checkpoints.save(value)
                    if self.game?.runID == value.runID && self.game?.play.phase != .completed { self.checkpoint = value }
                } catch { if !self.busy && self.game?.runID == draft.metadata.runID { self.fail(error, back: .deck) } }
            }
        } catch { fail(error, back: .deck) }
    }
    private func saveAndLeave() {
        guard let game else { show(.home); return }
        if game.play.phase == .completed {
            self.game = nil; audio.stop(); input.releaseOwner(); show(.home); return
        }
        game.pause(); audio.pause(); busy = true
        do {
            let draft = try game.prepareCheckpoint()
            if let source { local.checkpointSources[draft.metadata.runID.uuidString] = source.id; persist() }
            Task { [weak self] in
                guard let self else { return }
                do {
                    let value = try await Task.detached(priority: .utility) { try draft.encode() }.value
                    try await self.checkpoints.save(value)
                    self.checkpoint = value
                    self.game = nil; self.audio.stop(); self.input.releaseOwner(); self.busy = false; self.show(.home)
                } catch { self.preparation = nil; self.busy = false; self.fail(error, back: .deck) }
            }
        } catch { busy = false; fail(error, back: .deck) }
    }
    private func back() {
        if busy {
            guard preparation != nil else { return }
            cancelPreparation(); show(game == nil ? .home : .deck); return
        }
        switch route {
        case .home: return
        case .games, .players, .roster: show(.home)
        case .player: show(.players)
        case .settings: show(game == nil ? .home : .deck)
        case .audio: show(.settings)
        case .ranks: show(.games)
        case .levels: pageOffset = 0; show(.ranks)
        case .briefing: saveAndLeave()
        case .deck: if game?.play.phase == .suspended { return }; if game?.resume() == true { if let game { audio.start(game) }; showPlay() }
        case .results: saveAndLeave()
        case .error: show(previousRoute)
        default: show(.deck)
        }
    }
    private func cancelPreparation() { preparation?.cancel(); preparation = nil; generation = UUID(); busy = false }
    private func settingsChanged() {
        local.preferences = local.preferences.validated; game?.preferences = local.preferences; input.preferences = local.preferences
        audio.apply(local.preferences)
        persist(); show(.settings)
    }
    private func levelPreview(_ game: TVGameExperience) throws -> CGImage? {
        guard let image = MobileBitmapRenderer.image(try game.session.render(highlight: nil)) else { return nil }
        let visible = game.viewport.visibleLevelRect
        let scale = game.session.renderScale
        let crop = CGRect(x: visible.x * scale, y: visible.y * scale, width: visible.width * scale, height: visible.height * scale)
        return image.cropping(to: crop.integral) ?? image
    }
    private func persist() { if let bytes = try? JSONEncoder().encode(local) { UserDefaults.standard.set(bytes, forKey: "tv.localState") } }
    private func addPlayer() {
        let index = local.profiles.players.count
        if let id = local.profiles.add(name: "Player \(index + 1)") {
            local.profiles.setPortrait(id, to: index); editingPlayerID = id; persist()
        }
    }
    private func renamePlayer() {
        let id = editingPlayerID
        let alert = UIAlertController(title: L10n.text("Player name"), message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in field.text = self?.player(id).name; field.autocapitalizationType = .words }
        alert.addAction(UIAlertAction(title: L10n.text("Cancel"), style: .cancel))
        let save = UIAlertAction(title: L10n.text("Save"), style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text else { return }
            self.local.profiles.rename(id, to: name); self.persist(); self.show(.player)
        }
        alert.addAction(save); alert.preferredAction = save
        present(alert, animated: true)
    }
    private func player(_ id: String) -> MobileProfile { local.profiles.players.first(where: { $0.id == id }) ?? .init(id: id, name: "Player") }
    private func fail(_ error: Error, back: Route) { game?.pause(); audio.pause(); errorMessage = error.localizedDescription; previousRoute = back; show(.error) }
    private func wrapped(_ value: String, columns: Int) -> [String] {
        var lines: [String] = []; var line = ""
        for word in value.split(separator: " ") {
            if line.count + word.count + 1 > columns { lines.append(line); line = "" }
            line += (line.isEmpty ? "" : " ") + word
        }
        if !line.isEmpty { lines.append(line) }; return Array(lines.prefix(8))
    }
}
private extension MobilePixelFrame { var flatImage: CGImage? { MobileBitmapRenderer.image(self) } }
#endif
