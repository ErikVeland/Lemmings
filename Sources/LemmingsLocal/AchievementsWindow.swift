import AppKit
import NxlvKit

@MainActor final class AchievementsWindow {
  private var page: GameMenuPage?
  private var current = ClassicAchievementProgress()

  func show(progress: ClassicAchievementProgress) {
    update(progress: progress)
    if let page { GameScreen.shared.present(page) }
  }

  func update(progress: ClassicAchievementProgress) {
    current = progress
    let previous = page
    let wasVisible = previous.map { GameScreen.shared.contains($0) } ?? false
    let page = GameMenuPage(title: "Your rescue story", subtitle: "Campaign achievements · \(ArcadeStore.shared.records.activeProfile.initials)")
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    self.page = page
    let root = page.body
    let earned = ClassicAchievement.catalog.filter { progress.isUnlocked($0.id) }.count
    let title = label("Your rescue story", size: 26, weight: .bold)
    let subtitle = label("\(earned) of \(ClassicAchievement.catalog.count) achievements earned", size: 14)
    subtitle.textColor = .secondaryLabelColor
    let trophy = symbol("trophy.fill", color: .systemYellow, size: 44)
    let heading = NSStackView(views: [trophy, stack([title, subtitle], spacing: 5)])
    heading.spacing = 18
    let meter = NSProgressIndicator()
    meter.isIndeterminate = false
    meter.maxValue = Double(ClassicAchievement.catalog.count)
    meter.doubleValue = Double(earned)
    meter.setAccessibilityLabel("Achievements earned")
    let hint = label(earned == ClassicAchievement.catalog.count
      ? "Every achievement earned. What a rescue!"
      : "Play levels in order to work towards the next trophy.", size: 12)
    hint.textColor = .secondaryLabelColor
    let header = stack([heading, meter, hint], spacing: 12)
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.drawsBackground = false
    let rows = stack(ClassicAchievement.catalog.map { card($0) }, spacing: 10)
    let document = AchievementListView()
    scroll.documentView = document
    document.translatesAutoresizingMaskIntoConstraints = false
    rows.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(rows)
    for view in [header, scroll] {
      view.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(view)
    }
    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
      header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
      header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
      scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 20),
      scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
      rows.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
      rows.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
      rows.topAnchor.constraint(equalTo: document.topAnchor),
      rows.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
    ])

    if wasVisible, let previous {
      GameScreen.shared.dismiss(previous)
      GameScreen.shared.present(page)
    }
  }

  private func card(_ achievement: ClassicAchievement) -> NSView {
    let earned = current.isUnlocked(achievement.id)
    let card = NSBox()
    card.boxType = .custom
    card.titlePosition = .noTitle
    card.cornerRadius = 12
    card.borderWidth = 1
    card.borderColor = earned ? .systemGreen.withAlphaComponent(0.4) : .separatorColor
    card.fillColor = earned ? .systemGreen.withAlphaComponent(0.08) : .controlBackgroundColor
    card.contentViewMargins = NSSize(width: 16, height: 14)
    let title = label(achievement.title, size: 15, weight: .semibold)
    let detail = NSTextField(wrappingLabelWithString: achievement.detail)
    detail.font = .systemFont(ofSize: 12)
    detail.textColor = .secondaryLabelColor
    let status = label(earned ? "✓ Earned" : "Locked", size: 11, weight: .semibold)
    status.textColor = earned ? .systemGreen : .secondaryLabelColor
    let text = stack([title, detail, status], spacing: 4)
    let badge = symbol(icon(for: achievement.id),
      color: earned ? .systemGreen : .tertiaryLabelColor, size: 32)
    let row = NSStackView(views: [badge, text])
    row.spacing = 16
    row.alignment = .centerY
    text.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -56).isActive = true
    if let content = card.contentView {
      row.translatesAutoresizingMaskIntoConstraints = false
      content.addSubview(row)
      NSLayoutConstraint.activate([
        row.leadingAnchor.constraint(equalTo: content.leadingAnchor),
        row.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        row.topAnchor.constraint(equalTo: content.topAnchor),
        row.bottomAnchor.constraint(equalTo: content.bottomAnchor),
      ])
    }
    return card
  }

  private func icon(for id: ClassicAchievementID) -> String {
    switch id {
    case .firstRescue: return "figure.walk"
    case .xmas1991Complete, .xmas1992Complete, .holiday1993Complete,
         .holiday1994Complete, .festiveComplete: return "snowflake"
    case .lemmings2Complete: return "person.3.fill"
    case .lemmings3Complete: return "globe.europe.africa.fill"
    case .ohYesMoreLemmingsComplete: return "square.stack.3d.up.fill"
    case .trilogyComplete: return "star.circle.fill"
    case .fullCanonComplete: return "crown.fill"
    default: return "flag.checkered"
    }
  }

  private func label(_ text: String, size: CGFloat,
    weight: NSFont.Weight = .regular) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    return label
  }

  private func symbol(_ name: String, color: NSColor, size: CGFloat) -> NSImageView {
    let view = NSImageView()
    view.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    view.contentTintColor = color
    view.symbolConfiguration = .init(pointSize: size, weight: .medium)
    view.widthAnchor.constraint(equalToConstant: size + 8).isActive = true
    view.heightAnchor.constraint(equalToConstant: size + 8).isActive = true
    return view
  }

  private func stack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = spacing
    for view in views {
      view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    return stack
  }
}

private final class AchievementListView: NSView {
  override var isFlipped: Bool { true }
}
