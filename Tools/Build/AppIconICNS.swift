import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("Usage: AppIconICNS.swift <iconset directory> <output.icns>")
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let sizes = [16, 32, 128, 256, 512]
let iconNames = sizes.flatMap { size in
    ["icon_\(size)x\(size).png", "icon_\(size)x\(size)@2x.png"]
}

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    "com.apple.icns" as CFString,
    iconNames.count,
    nil
) else {
    fail("Could not create \(outputURL.path)")
}

for name in iconNames {
    let imageURL = iconsetURL.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("Could not read \(imageURL.path)")
    }

    let retina = name.contains("@2x")
    let size = Int(name.split(separator: "x")[0].dropFirst(5)) ?? 0
    let expectedPixels = size * (retina ? 2 : 1)
    guard image.width == expectedPixels, image.height == expectedPixels else {
        fail("Unexpected dimensions for \(imageURL.path)")
    }

    let dpi = retina ? 144.0 : 72.0
    let properties: [CFString: Any] = [
        kCGImagePropertyDPIWidth: dpi,
        kCGImagePropertyDPIHeight: dpi,
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
}

guard CGImageDestinationFinalize(destination),
      let result = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
      CGImageSourceGetCount(result) == iconNames.count else {
    fail("Could not verify \(outputURL.path)")
}
