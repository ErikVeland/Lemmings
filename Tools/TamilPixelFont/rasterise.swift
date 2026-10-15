#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO

/**
 * Shapes complete Tamil sequences before rasterisation. Run through build.sh.
 */
struct Entry: Decodable {
    let id: String
    let text: String
}
struct Repertoire: Decodable { let entries: [Entry] }
struct GlyphRecord: Encodable {
    let id: String, text: String, displayText: String, mask: String
    let advance: Int, x: Int, y: Int, width: Int, height: Int
    let glyphIds: [UInt16], sourceFonts: [String]
    let missingGlyph: Bool, diagnosticOnly: Bool
}
struct FaceRecord: Encodable {
    let id: String
    let bodyHeight: Int, baseline: Int, lineHeight: Int
    let glyphs: [GlyphRecord]
}
struct FontSource: Encodable {
    let file: String, postScriptName: String, version: String
}
struct Manifest: Encodable {
    let samplingScale: Int
    let renderer: String
    let fontSources: [FontSource]
    let faces: [FaceRecord]
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let destination = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : root.appendingPathComponent("output/raw", isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
let repertoire = try JSONDecoder().decode(Repertoire.self, from: Data(contentsOf: root.appendingPathComponent("repertoire.json")))
let sampleScale = 4

func sourceFont(_ name: String, size: CGFloat) throws -> CTFont {
    let url = root.appendingPathComponent("vendor/\(name).ttf")
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
          let descriptor = descriptors.first else {
        throw NSError(domain: "TamilPixelFont", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read \(url.path)."])
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    return CTFontCreateWithFontDescriptor(descriptor, size, nil)
}
func line(_ text: String, font: CTFont) -> CTLine {
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
        NSAttributedString.Key(kCTLigatureAttributeName as String): 1
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
}
func savePNG(_ context: CGContext, at url: URL) throws {
    guard let image = context.makeImage(),
          let writer = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "TamilPixelFont", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create \(url.path)."])
    }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else {
        throw NSError(domain: "TamilPixelFont", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot save \(url.path)."])
    }
}

let prototype = try sourceFont("NotoSansTamil-Bold", size: 100)
let bodyBounds = CTLineGetBoundsWithOptions(line("அஆஇஈஉஊஎஏஐஒஓஔகஙசஞடணதநபமயரலவழளறன", font: prototype), [.useGlyphPathBounds])
var faces: [FaceRecord] = []
for (faceID, bodyHeight) in [("small", 14), ("large", 18), ("detail", 26)] {
    let pointSize = CGFloat(bodyHeight) * 100 / bodyBounds.height
    let font = try sourceFont("NotoSansTamil-Bold", size: pointSize)
    let supplement = try sourceFont("NotoSansTamilSupplement-Regular", size: pointSize)
    let latin = try sourceFont("NotoSans-Bold", size: pointSize)
    let folder = destination.appendingPathComponent(faceID, isDirectory: true)
    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    var glyphs: [GlyphRecord] = []
    for entry in repertoire.entries {
        let firstCategory = entry.text.unicodeScalars.first?.properties.generalCategory
        let diagnosticOnly = firstCategory == .spacingMark || firstCategory == .nonspacingMark || firstCategory == .enclosingMark
        let displayText = diagnosticOnly ? "◌" + entry.text : entry.text
        let selected = entry.text.unicodeScalars.allSatisfy(\.isASCII) ? latin
            : entry.text.unicodeScalars.contains { (0x11FC0...0x11FFF).contains($0.value) } ? supplement : font
        let shaped = line(displayText, font: selected)
        let bounds = CTLineGetBoundsWithOptions(shaped, [.useGlyphPathBounds])
        let left = bounds.isNull ? -1 : Int(floor(bounds.minX)) - 1
        let top = bounds.isNull ? 1 : Int(ceil(bounds.maxY)) + 1
        let right = bounds.isNull ? 1 : Int(ceil(bounds.maxX)) + 1
        let bottom = bounds.isNull ? -1 : Int(floor(bounds.minY)) - 1
        let width = max(2, right - left), height = max(2, top - bottom)
        guard let context = CGContext(data: nil, width: width * sampleScale, height: height * sampleScale,
            bitsPerComponent: 8, bytesPerRow: width * sampleScale,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            fatalError("Cannot allocate the glyph mask.")
        }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width * sampleScale, height: height * sampleScale))
        context.scaleBy(x: CGFloat(sampleScale), y: CGFloat(sampleScale))
        context.translateBy(x: CGFloat(-left), y: CGFloat(-bottom))
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(false)
        context.setShouldSubpixelPositionFonts(false)
        context.textPosition = .zero
        CTLineDraw(shaped, context)
        let mask = "\(faceID)/\(entry.id).png"
        try savePNG(context, at: destination.appendingPathComponent(mask))
        let runs = CTLineGetGlyphRuns(shaped) as! [CTRun]
        var glyphIDs: [UInt16] = [], fontNames: Set<String> = []
        for run in runs {
            var ids = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &ids)
            glyphIDs += ids
            let attributes = CTRunGetAttributes(run) as NSDictionary
            if let runFont = attributes[kCTFontAttributeName] {
                fontNames.insert(CTFontCopyPostScriptName(runFont as! CTFont) as String)
            }
        }
        let advance = max(1, Int(ceil(CTLineGetTypographicBounds(shaped, nil, nil, nil)))) + 1
        glyphs.append(GlyphRecord(id: entry.id, text: entry.text, displayText: displayText,
            mask: mask, advance: advance, x: left, y: -top, width: width, height: height,
            glyphIds: glyphIDs, sourceFonts: fontNames.sorted(), missingGlyph: glyphIDs.contains(0), diagnosticOnly: diagnosticOnly))
    }
    let baseline = (glyphs.map { -$0.y }.max() ?? bodyHeight) + 1
    let bottom = glyphs.map { $0.y + $0.height }.max() ?? 0
    faces.append(FaceRecord(id: faceID, bodyHeight: bodyHeight, baseline: baseline,
        lineHeight: baseline + bottom + 2, glyphs: glyphs))
    print("\(faceID): \(glyphs.count) sequences, \(glyphs.filter(\.missingGlyph).count) missing glyphs, baseline \(baseline), line height \(baseline + bottom + 2)")
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let fontSources = try ["NotoSansTamil-Bold", "NotoSansTamilSupplement-Regular", "NotoSans-Bold"].map { name in
    let font = try sourceFont(name, size: 100)
    return FontSource(file: "vendor/\(name).ttf", postScriptName: CTFontCopyPostScriptName(font) as String,
        version: CTFontCopyName(font, kCTFontVersionNameKey) as String? ?? "unknown")
}
try encoder.encode(Manifest(samplingScale: sampleScale, renderer: "Apple Core Text", fontSources: fontSources, faces: faces))
    .write(to: destination.appendingPathComponent("manifest.json"))
