import CoreGraphics
import CoreImage
import Foundation
import NxlvKit

/// One destination for menu, About and television support links.
public enum GameSupport {
    public static let coffeeURL = URL(string: "https://coff.ee/generik")!
    public static var menuAction: GameFrontEnd.Action { .init("donate", L10n.text("Donate")) }
    public static var page: GameFrontEnd.Page {
        .init(title: L10n.text("Buy me a coffee"), details: ["coff.ee/generik"],
              footer: [.init("home", L10n.text("Back"))], preview: true)
    }

    public static let qrCode: CGImage? = {
        guard let filter = CIFilter(name: "CIQRCodeGenerator", parameters: [
            "inputMessage": Data(coffeeURL.absoluteString.utf8), "inputCorrectionLevel": "M"]),
              let output = filter.outputImage,
              let image = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(output, from: output.extent),
              let context = CGContext(data: nil, width: image.width + 8, height: image.height + 8,
                bitsPerComponent: 8, bytesPerRow: (image.width + 8) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 4, y: 4, width: image.width, height: image.height))
        return context.makeImage()
    }()
}
