#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit

extension AppDelegate {
  fileprivate func testFanLevelOrganisation() async throws {
    if window == nil { buildInterface() }
    settings.music = .silent
    loadContent()
    guard let discovery = await makeLevelBrowserDiscoveryTask().value else {
      throw IntegrationFailure(message: "Fan library discovery failed")
    }
    rebuildLevelCatalogue(discovery)
    let root = fanLevelGroups()
    try check(root.packIDs.count >= 535, "Fan packs disappeared from the grouped library")
    var paths: [[String]] = [[]]
    func visit(_ group: FanLevelOrganisation.Group, path: [String]) {
      for child in group.children where child.packID == nil {
        let next = path + [child.id]; paths.append(next); visit(child, path: next)
      }
    }
    visit(root, path: [])
    let output = URL(fileURLWithPath: ".build/fan-library-ui")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for size in [CGSize(width: 900, height: 620), .init(width: 1120, height: 720), .init(width: 1600, height: 1000)] {
      window.setContentSize(size)
      for path in paths {
        GameScreen.shared.dismissAll()
        let page = FanLevelGroupPage(root: root, path: path)
        var selected: String?
        page.onSelect = { selected = $0.id }
        GameScreen.shared.present(page, owner: window)
        window.contentView?.layoutSubtreeIfNeeded()
        try check(page.groupButtons.count <= 10, "A fan page exceeded ten rows")
        for (index, button) in page.groupButtons.enumerated() {
          try check(page.body.bounds.contains(button.frame), "A fan group fell outside the menu body: \(button.title)")
          try check(button.frame.width >= 44 && button.frame.height >= 44, "A fan group has a small input target")
          let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: page)
          try check(page.hitTest(point) === button, "A fan group lost its input target")
          try check(button.accessibilityLabel()?.isEmpty == false, "A fan group lost its accessible name")
          if let renderer = GameMenuArtwork.renderer() {
            try check(GameTextLayout.height(button.title, width: button.bounds.width - 24, face: .small,
              font: renderer.font(.small)) <= button.bounds.height - 12, "A fan caption was truncated: \(button.title)")
          }
          for other in page.groupButtons where other !== button {
            try check(!button.frame.intersects(other.frame), "Fan group targets overlap")
          }
          if let action = button.action { NSApp.sendAction(action, to: button.target, from: button) }
          try check(selected == page.groups[index].id, "A fan button opened the wrong group")
        }
        if path.count <= 1 || path.last == "series:mikepak" {
          let view = window.contentView!
          let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
          view.cacheDisplay(in: view.bounds, to: bitmap)
          let name = path.isEmpty ? "root" : path.joined(separator: "-").replacingOccurrences(of: ":", with: "-")
          try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("mac-\(Int(size.width))-\(name).png"))
        }
      }
    }
    GameScreen.shared.dismissAll()
    presentFanLevelGroups()
    let source = fanGroupPages[0]
    let fanIndex = source.groups.firstIndex { $0.id == "fan" }!
    window.makeFirstResponder(source.groupButtons[fanIndex])
    source.groupButtons[fanIndex].performClick(nil)
    try check(fanGroupPages.last?.path == ["fan"], "Fan category navigation failed")
    fanGroupPages.last?.controllerBackButton.performClick(nil)
    try check(GameScreen.shared.controllerPage(in: window) === source, "Back did not restore the fan root")
    try check(window.firstResponder === source.groupButtons[fanIndex], "Back lost the selected fan category")
    try check(levelPackItems(for: levelCatalogue.packs).filter { $0.id == "fan-library" }.count == 1,
      "Level Select did not consolidate the fan catalogue")
    GameScreen.shared.dismissAll()

    guard let resources = Bundle.main.resourceURL,
          let typography = GameMenuTypography(directory: resources.appendingPathComponent("MacArtwork/lemmings")) else {
      throw IntegrationFailure(message: "Fan library bitmap artwork is missing")
    }
    for (name, size) in [("phone", CGSize(width: 390, height: 760)), ("landscape", .init(width: 760, height: 350)),
                         ("tablet", .init(width: 834, height: 1110)), ("tv", .init(width: 1920, height: 1080))] {
      for path in [[], ["learning"], ["magazines"], ["fan"], ["community"], ["ports"]] {
        let page = FanLevelLibraryArt.page(root: root, path: path)
        let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
        try check(page.rows.count <= 10, "A mobile fan page exceeded ten rows")
        for target in layout.targets {
          try check(target.frame.width >= 44 && target.frame.height >= 44, "A mobile fan target is too small")
          try check(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
            "A mobile fan target opened another item")
          try check(CGRect(origin: .zero, size: layout.size).contains(target.frame), "A mobile fan target was clipped")
          for other in layout.targets where target.action.id != other.action.id {
            try check(!target.frame.intersects(other.frame), "Mobile fan targets overlap")
          }
        }
        let context = CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8,
          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
        GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: page.rows.first?.id, in: context)
        let image = NSBitmapImageRep(cgImage: context.makeImage()!)
        try image.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name)-\(path.first ?? "root").png"))
      }
    }
    print("PASS grouped fan corpus, Mac navigation and targets at three sizes, phone/tablet/TV bitmap targets and captures")
  }
}
#endif
