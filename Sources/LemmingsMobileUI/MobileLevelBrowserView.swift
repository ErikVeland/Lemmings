#if os(iOS)
import LemmingsMobileCore
import LemmingsGameArt
import UIKit

/// The wide level page: a CoverFlow carousel with the Mac level browser's actions beneath it.
@MainActor final class MobileLevelBrowserView: UIView {
    var artworkLoader: ((Int) async -> CGImage?)? { didSet { flow.artworkLoader = artworkLoader } }
    var onBack: (() -> Void)?
    var onPlay: ((Int) -> Void)?
    var onSelect: ((Int) -> Void)?
    var onFavourite: ((Int) -> Void)?

    private let backdrop = MobileMenuBackdrop()
    private let titleLabel = MobilePixelLabel()
    private let subtitleLabel = MobilePixelLabel()
    private let flow = MobileCoverFlowView()
    private let back = MobilePixelButton()
    private let rankPrevious = MobilePixelButton()
    private let rankNext = MobilePixelButton()
    private let favourite = MobilePixelButton()
    private let play = MobilePixelButton()
    private var levels: [MobileLevelSummary] = []
    private var hasRanks = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        titleLabel.palette = .green
        titleLabel.face = .large
        back.title = "BACK"
        rankPrevious.title = "< RANK"
        rankNext.title = "RANK >"
        favourite.title = "FAVOURITE"
        play.title = "PLAY"
        play.isPrimary = true
        back.onPress = { [weak self] in self?.onBack?() }
        rankPrevious.onPress = { [weak self] in self?.moveRank(-1) }
        rankNext.onPress = { [weak self] in self?.moveRank(1) }
        favourite.onPress = { [weak self] in
            guard let self, self.levels.indices.contains(self.flow.selectedIndex) else { return }
            self.onFavourite?(self.levels[self.flow.selectedIndex].index)
        }
        play.onPress = { [weak self] in
            guard let self, self.levels.indices.contains(self.flow.selectedIndex) else { return }
            self.onPlay?(self.levels[self.flow.selectedIndex].index)
        }
        flow.onSelectionChanged = { [weak self] index in self?.selectionChanged(index) }
        flow.onActivate = { [weak self] index in
            guard let self, self.levels.indices.contains(index) else { return }
            self.onPlay?(self.levels[index].index)
        }
        [backdrop, titleLabel, subtitleLabel, flow, back, rankPrevious, rankNext, favourite, play].forEach(addSubview)
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
    }

    var selectedLevel: Int? {
        levels.indices.contains(flow.selectedIndex) ? levels[flow.selectedIndex].index : nil
    }

    private func selectionChanged(_ position: Int) {
        guard levels.indices.contains(position) else { return }
        let level = levels[position]
        let rank = levels.filter { $0.rank == level.rank }
        titleLabel.text = level.title
        subtitleLabel.text = "\(level.rank)  \(level.number)/\(rank.count)"
        onSelect?(level.index)
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
        let buttons = hasRanks ? [back, rankPrevious, rankNext, favourite, play] : [back, favourite, play]
        let layout = LevelBrowserGeometry(safe: MobileSystemRegions.menuFrame(in: self), actionCount: buttons.count)
        backdrop.frame = bounds
        backdrop.board = layout.board
        titleLabel.frame = layout.title
        subtitleLabel.frame = layout.subtitle
        for (button, frame) in zip(buttons, layout.actions) { button.frame = frame }
        flow.frame = layout.stage
    }
}
#endif
