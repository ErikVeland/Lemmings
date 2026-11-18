import Foundation
import TVServices

/**
 * Shows the Home scenery clip, or retains the static artwork when no clip exists.
 * Keeps the group, folder and manifest fields in step with `MobileTopShelfScenery`.
 */
final class ContentProvider: TVTopShelfContentProvider {
    private struct Manifest: Decodable {
        var title: String?
        var image: String
        var video: String?
    }

    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        completionHandler(content())
    }

    private func content() -> (any TVTopShelfContent)? {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.academy.glasscode.lemmings")?
                .appendingPathComponent("Library/Caches/TopShelf", isDirectory: true),
              let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
        let image = folder.appendingPathComponent(manifest.image)
        guard FileManager.default.fileExists(atPath: image.path) else { return nil }

        let item = TVTopShelfCarouselItem(identifier: "home-scenery")
        item.title = manifest.title ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "")
        item.setImageURL(image, for: .screenScale1x)
        item.setImageURL(image, for: .screenScale2x)
        if let video = manifest.video.map(folder.appendingPathComponent),
           FileManager.default.fileExists(atPath: video.path) {
            item.previewVideoURL = video
        }
        if let scheme = Bundle.main.object(forInfoDictionaryKey: "TopShelfLaunchURLScheme") as? String,
           let url = URL(string: "\(scheme)://home") {
            item.playAction = TVTopShelfAction(url: url)
            item.displayAction = TVTopShelfAction(url: url)
        }
        return TVTopShelfCarouselContent(style: .actions, items: [item])
    }
}
