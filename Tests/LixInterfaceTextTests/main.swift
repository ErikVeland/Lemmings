import Foundation
import CoreGraphics
import ImageIO
import NxlvKit

struct Failure: Error { let message: String }
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(message: message) }
}

do {
    let folder = URL(fileURLWithPath: CommandLine.arguments[1])
    let font = try LixInterfaceText(directory: folder)
    guard let frame = font.frame("LIX 0123 ABC xyz", pixelSize: 16, red: 115, green: 255, blue: 26) else {
        throw Failure(message: "The source font did not rasterise.")
    }
    try check(frame.width > 100 && frame.height >= 16, "The source font metrics are invalid.")
    let bytes = [UInt8](frame.rgba)
    let opaque = stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0 + 3] != 0 }
    try check(opaque.count > 100, "The source font line is blank.")
    try check(opaque.allSatisfy { bytes[$0] == 115 && bytes[$0 + 1] == 255 && bytes[$0 + 2] == 26
        && bytes[$0 + 3] == 255 }, "The source font pixels are blurred or use the wrong palette: \(opaque.prefix(5).map { Array(bytes[$0..<($0 + 4)]) })")
    try check(font.frame("😀", pixelSize: 16) == nil, "An unavailable glyph used a system-font fallback.")
    try check(font.frame("LIX", pixelSize: 0) == nil, "An invalid font size was accepted.")
    try check(font.frame(String(repeating: "A", count: 1_025), pixelSize: 12) == nil, "The text bound was ignored.")
    let instructions = "Select the Classic folder, then choose Import to TV. Keep this page open until the transfer finishes."
    guard let paragraph = font.paragraph(instructions, width: 280, height: 60,
        maximumLines: 3, maximumPixelSize: 24) else { throw Failure(message: "The complete instructions did not fit.") }
    try check(!paragraph.isEmpty && paragraph.count <= 3 && paragraph.allSatisfy { $0.width <= 280 && $0.height <= 20 },
              "The paragraph exceeds its rendered bounds.")
    try check(font.paragraph(instructions, width: 1, height: 10, maximumLines: 1,
        maximumPixelSize: 12) == nil, "A failed paragraph fit silently dropped text.")
    do {
        _ = try LixInterfaceText(data: Data([1, 2, 3]))
        throw Failure(message: "An invalid font was accepted.")
    } catch is LixInterfaceText.DecodeError { }
    let provider = CGDataProvider(data: frame.rgba as CFData)!
    let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
        bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let url = URL(fileURLWithPath: CommandLine.arguments[2])
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    try check(CGImageDestinationFinalize(destination), "The font proof could not be saved.")
    print("PASS pinned Lix font pixels, metrics, palette, complete paragraph fitting, bounds and unavailable-glyph rejection")
} catch {
    FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
    exit(1)
}
