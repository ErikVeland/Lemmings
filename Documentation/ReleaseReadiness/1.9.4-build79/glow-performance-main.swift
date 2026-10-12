import AppKit
import Foundation

struct RenderFailure: Error { let message: String }
func require(_ value: Bool, _ message: String) throws {
    if !value { throw RenderFailure(message: message) }
}
let width = 1280, height = 640
let colourSpace = CGColorSpaceCreateDeviceRGB()
@MainActor func bitmap() -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: colourSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
let art = bitmap()
art.setFillColor(CGColor(gray: 0, alpha: 1)); art.fill(CGRect(x: 0, y: 0, width: width, height: height))
art.setFillColor(NSColor(red: 0.55, green: 0.08, blue: 0.06, alpha: 1).cgColor)
art.fill(CGRect(x: 140, y: 160, width: 1000, height: 120))
let source = art.makeImage()!
let context = bitmap()
context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
let rect = CGRect(x: 0, y: 0, width: width, height: height)
@MainActor func base() {
    context.saveGState(); context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
    context.draw(source, in: rect); context.restoreGState()
}
base()
let inactive = context.makeImage()!.dataProvider!.data! as Data
let glow = RescueBackgroundGlow()
var earned: Data = inactive
for _ in 0..<100 {
    base(); glow.draw(source, in: rect, amount: 1, context: context, slot: "scene")
    earned = context.makeImage()!.dataProvider!.data! as Data
    if earned != inactive { break }
    try await Task.sleep(nanoseconds: 10_000_000)
}
try require(earned != inactive, "The asynchronous glow did not become visible")
let far = (height / 2 * width + 20) * 4
try require(earned[far] == inactive[far] && earned[far+1] == inactive[far+1], "The glow washed empty space")
var changed = 0, maximumChannelDelta = 0
for pixel in stride(from: 0, to: earned.count, by: 4) {
    for channel in 0..<3 {
        let delta = abs(Int(earned[pixel+channel])-Int(inactive[pixel+channel]))
        maximumChannelDelta = max(maximumChannelDelta,delta)
        if delta > 0 { changed += 1 }
    }
}
try require(maximumChannelDelta <= 15, "The background glow exceeded its faint SDR cap")
let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("glow.png"))
var milliseconds: [Double] = []
for _ in 0..<1000 {
    let frame = CGImage(width: source.width, height: source.height, bitsPerComponent: source.bitsPerComponent,
        bitsPerPixel: source.bitsPerPixel, bytesPerRow: source.bytesPerRow, space: source.colorSpace!,
        bitmapInfo: source.bitmapInfo, provider: source.dataProvider!, decode: nil,
        shouldInterpolate: false, intent: .defaultIntent)!
    base()
    let start = ProcessInfo.processInfo.systemUptime
    glow.draw(frame, in: rect, amount: 1, context: context, slot: "scene")
    milliseconds.append((ProcessInfo.processInfo.systemUptime-start)*1000)
}
let sorted = milliseconds.sorted(), p95 = sorted[Int(Double(sorted.count)*0.95)]
try require(p95 < 12, "Cached glow draws consume the fast-forward input budget")
let result: [String: Any] = ["frameCount": milliseconds.count, "sourceImageReplacedEveryFrame": true,
    "changedChannels": changed, "maximumChannelDelta": maximumChannelDelta,
    "glowDrawP95Milliseconds": p95, "glowDrawMaximumMilliseconds": sorted.last!,
    "scope": "Windowless 1280x640 bitmap draw with the actual production helper, fresh scene identities and a warmed async glow. Does not certify whole-game throughput or physical HDR."]
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys]).write(
    to: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("glow-performance.json"))
print("PASS asynchronous glow, faint SDR cap, empty-space preservation and 1000 fresh-image draws; p95 \(p95) ms")
