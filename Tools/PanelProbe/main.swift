import CoreGraphics
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

// Decodes a MAIN.DAT section as planar graphics and writes a PNG, so a
// candidate interpretation can be checked by eye instead of by guesswork.

let arguments = CommandLine.arguments
func flag(_ name: String, _ fallback: String) -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        return fallback
    }
    return arguments[index + 1]
}

let directory = URL(fileURLWithPath: flag("--data", "Content/lemming1.pc"), isDirectory: true)
let sectionIndex = Int(flag("--section", "2"))!
let width = Int(flag("--width", "320"))!
let height = Int(flag("--height", "40"))!
let bpp = Int(flag("--bpp", "4"))!
let offset = Int(flag("--offset", "0"))!
let output = flag("--out", "panel.png")
// Some images store the four planes per row instead of one whole plane
// after another. This tries that arrangement.
let rowInterleaved = arguments.contains("--interleave")

let files = try FileManager.default.contentsOfDirectory(
    at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
guard let url = files.first(where: { $0.lastPathComponent.lowercased() == "main.dat" }) else {
    FileHandle.standardError.write(Data("MAIN.DAT not found\n".utf8))
    exit(1)
}
let sections = try ClassicDATArchive.decode(try Data(contentsOf: url))
guard sectionIndex < sections.count else {
    FileHandle.standardError.write(Data("no section \(sectionIndex)\n".utf8))
    exit(1)
}
let data = [UInt8](sections[sectionIndex].data)
if let dump = ProcessInfo.processInfo.environment["DUMP_SECTION"] {
    try? Data(data).write(to: URL(fileURLWithPath: dump))
    print("dumped section \(sectionIndex): \(data.count) bytes -> \(dump)")
}

let pixelCount = width * height
let bytesPerPlane = (pixelCount + 7) / 8
let needed = offset + bytesPerPlane * bpp
guard data.count >= needed else {
    FileHandle.standardError.write(Data(
        "section \(sectionIndex) has \(data.count) bytes, need \(needed)\n".utf8))
    exit(1)
}

var pixels = [UInt8](repeating: 0, count: pixelCount)
if rowInterleaved {
    let rowBytes = (width + 7) / 8
    for y in 0..<height {
        let rowStart = offset + y * rowBytes * bpp
        for plane in 0..<bpp {
            let planeStart = rowStart + plane * rowBytes
            for x in 0..<width {
                let index = planeStart + x / 8
                guard index < data.count else { continue }
                let bit = (data[index] >> UInt8(7 - x % 8)) & 1
                pixels[y * width + x] |= bit << UInt8(plane)
            }
        }
    }
} else {
    for plane in 0..<bpp {
        let planeOffset = offset + plane * bytesPerPlane
        for pixel in 0..<pixelCount {
            let byte = data[planeOffset + pixel / 8]
            let bit = (byte >> UInt8(7 - pixel % 8)) & 1
            pixels[pixel] |= bit << UInt8(plane)
        }
    }
}

// A readable 16-entry ramp. The real palette comes later; this is for shape.
let palette: [(UInt8, UInt8, UInt8)] = [
    (0, 0, 0), (60, 60, 90), (90, 90, 130), (120, 120, 170),
    (160, 160, 200), (200, 200, 230), (255, 255, 255), (200, 60, 60),
    (230, 120, 60), (240, 200, 80), (80, 200, 100), (60, 160, 220),
    (150, 90, 200), (110, 70, 40), (170, 120, 80), (240, 160, 180),
]

var rgba = [UInt8]()
rgba.reserveCapacity(pixelCount * 4)
var histogram = [Int](repeating: 0, count: 16)
for value in pixels {
    let index = Int(value) & 0x0F
    histogram[index] += 1
    let color = palette[index]
    rgba.append(contentsOf: [color.0, color.1, color.2, 255])
}

guard let provider = CGDataProvider(data: Data(rgba) as CFData),
    let image = CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
            .union(.byteOrder32Big),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    FileHandle.standardError.write(Data("could not encode PNG\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }

let used = histogram.enumerated().filter { $0.element > 0 }.map { "\($0.offset):\($0.element)" }
print("section \(sectionIndex): \(data.count) bytes, decoded \(width)x\(height) at \(bpp)bpp")
print("  consumed \(needed) of \(data.count) bytes, \(data.count - needed) left over")
print("  colour use: \(used.joined(separator: " "))")
print("  wrote \(output)")
