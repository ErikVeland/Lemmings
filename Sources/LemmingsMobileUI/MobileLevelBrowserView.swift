#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import NxlvKit
import LemmingsGameArt
import UIKit

/// The wide level page: a CoverFlow carousel with the Mac level browser's actions beneath it.
@MainActor final class MobileLevelBrowserView: UIView {
    var artworkLoader: ((Int) async -> CGImage?)? { didSet { flow.artworkLoader = artworkLoader } }
    var artworkLoadingEnabled: Bool {
        get { flow.artworkLoadingEnabled }
        set { flow.artworkLoadingEnabled = newValue }
    }
    func stopArtworkLoading() -> Task<Void, Never>? { flow.stopArtworkLoading() }
    var onBack: (() -> Void)?
    var onPlay: ((Int) -> Void)?
    var onSelect: ((Int) -> Void)?
    var onFavourite: ((Int) -> Void)?
    var onPlaylist: ((Int) -> Void)?
    var showsBack = true { didSet { if showsBack != oldValue { setNeedsLayout() } } }

    var playerName: String? { didSet { if oldValue != playerName { updateSubtitle() } } }
    var statusText = "" { didSet { if oldValue != statusText { updateSubtitle(); setNeedsLayout() } } }
    var isLoading = false { didSet { play.isEnabled = !isLoading } }
    private let backdrop = MobileMenuBackdrop()
    private let titleLabel = MobilePixelLabel()
    private let subtitleLabel = MobilePixelLabel()
    private let flow = MobileCoverFlowView()
    private let back = MobilePixelButton()
    private let rankPrevious = MobilePixelButton()
    private let rankNext = MobilePixelButton()
    private let favourite = MobilePixelButton()
    private let playlist = MobilePixelButton()
    private let play = MobilePixelButton()
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] { [flow] }
    #endif
    private var levels: [MobileLevelSummary] = []
    private var hasRanks = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        titleLabel.palette = .green
        titleLabel.face = .large
        titleLabel.wraps = true
        subtitleLabel.wraps = true
        back.title = L10n.text("BACK")
        rankPrevious.title = L10n.text("< RANK")
        rankNext.title = L10n.text("RANK >")
        favourite.title = L10n.text("FAVOURITE")
        favourite.icon = .favourite
        playlist.title = L10n.text("PLAYLIST")
        play.title = L10n.text("PLAY")
        play.isPrimary = true
        back.onPress = { [weak self] in self?.onBack?() }
        rankPrevious.onPress = { [weak self] in self?.moveRank(-1) }
        rankNext.onPress = { [weak self] in self?.moveRank(1) }
        favourite.onPress = { [weak self] in
            guard let self, self.levels.indices.contains(self.flow.selectedIndex) else { return }
            self.onFavourite?(self.levels[self.flow.selectedIndex].index)
        }
        playlist.onPress = { [weak self] in
            guard let self, self.levels.indices.contains(self.flow.selectedIndex) else { return }
            self.onPlaylist?(self.levels[self.flow.selectedIndex].index)
        }
        play.onPress = { [weak self] in
            guard let self, !self.isLoading, self.levels.indices.contains(self.flow.selectedIndex) else { return }
            self.onPlay?(self.levels[self.flow.selectedIndex].index)
        }
        flow.onSelectionChanged = { [weak self] index in self?.selectionChanged(index) }
        flow.onActivate = { [weak self] index in
            guard let self, !self.isLoading, self.levels.indices.contains(index) else { return }
            self.onPlay?(self.levels[index].index)
        }
        [backdrop, titleLabel, subtitleLabel, flow, back, rankPrevious, rankNext, favourite, playlist, play].forEach(addSubview)
    }

    required init?(coder: NSCoder) { nil }

    func configure(levels: [MobileLevelSummary], selected: Int) {
        self.levels = levels
        hasRanks = Set(levels.map(\.rank)).count > 1
        rankPrevious.isHidden = !hasRanks
        rankNext.isHidden = !hasRanks
        setNeedsLayout()
        flow.titles = levels.map { "\($0.number)  \($0.title)" }
        let position = levels.firstIndex { $0.index == selected } ?? 0
        flow.select(position, animated: false)
        selectionChanged(position)
    }

    /// Marks the current level as starred or not.
    func setFavourite(_ on: Bool) {
        favourite.isSelectedState = on
        favourite.accessibilityLabel = on ? L10n.text("Remove favourite") : L10n.text("Add favourite")
        favourite.accessibilityValue = on ? "1" : "0"
    }

    var selectedLevel: Int? {
        levels.indices.contains(flow.selectedIndex) ? levels[flow.selectedIndex].index : nil
    }

    private func selectionChanged(_ position: Int) {
        guard levels.indices.contains(position) else { return }
        let level = levels[position]
        titleLabel.text = level.title
        updateSubtitle()
        setNeedsLayout()
        onSelect?(level.index)
    }

    private func updateSubtitle() {
        guard levels.indices.contains(flow.selectedIndex) else { return }
        let level = levels[flow.selectedIndex]
        let rank = levels.filter { $0.rank == level.rank }
        let subtitle = [level.selectionSubtitle(rankCount: rank.count, status: statusText),
            AmigaVersusCampaign.controllerRequirement(rank: level.rank)].compactMap { $0 }.joined(separator: "\n")
        subtitleLabel.text = MobileTurnArt.subtitle(subtitle, playerName: playerName, role: .next)
    }

    private func moveRank(_ offset: Int) {
        guard levels.indices.contains(flow.selectedIndex) else { return }
        var ranks: [String] = []
        for level in levels where !ranks.contains(level.rank) { ranks.append(level.rank) }
        guard let current = ranks.firstIndex(of: levels[flow.selectedIndex].rank), !ranks.isEmpty else { return }
        let next = ranks[(current + offset + ranks.count) % ranks.count]
        if let position = levels.firstIndex(where: { $0.rank == next }) { flow.select(position, animated: true) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A short screen has room for four actions in a row, so the rank pair steps aside.
        // The carousel itself still reaches every level.
        let wideRoom = bounds.height >= 430
        let buttons = (showsBack ? [back] : []) + (hasRanks && wideRoom ? [rankPrevious, rankNext] : [])
            + [favourite, playlist, play]
        back.isHidden = !showsBack
        for button in [rankPrevious, rankNext] { button.isHidden = !(hasRanks && wideRoom) }
        let layout = LevelBrowserGeometry(safe: MobileSystemRegions.menuFrame(in: self), actionCount: buttons.count, titleText: titleLabel.text, subtitleText: subtitleLabel.text,
            actionTitles: buttons.map { $0.icon == .favourite ? "" : $0.title },
            includesBack: showsBack, rankActions: hasRanks && wideRoom ? (showsBack ? 1..<3 : 0..<2) : nil,
            occlusions: MobileSystemRegions.usesFullDisplay(in: self) ? MobileSystemRegions.read(in: self) : [])
        backdrop.frame = bounds
        backdrop.board = layout.board
        titleLabel.frame = layout.title
        subtitleLabel.frame = layout.subtitle
        for (button, frame) in zip(buttons, layout.actions) { button.frame = frame }
        flow.frame = layout.stage
    }
}
#endif
