import Foundation
import NxlvKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let l2 = root.appendingPathComponent("Sources/Ports/Lemm2")
let l3 = root.appendingPathComponent("Sources/Ports/LEM3CD")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
var records: [[String: Any]] = []
func read(_ base: URL, _ path: String) throws -> Data { try Data(contentsOf: base.appendingPathComponent(path)) }
func frame(_ f: Lemmings2SpriteFrame, _ palette: [UInt8]) throws -> SequelMacFrame {
    try .init(width: f.width, height: f.height, x: f.x, y: f.y, pixels: f.pixels, palette: palette, opaque: f.opaque)
}
func frame(_ f: SequelIndexedImage, transparent: UInt8? = nil) throws -> SequelMacFrame {
    try .init(width: f.width, height: f.height, pixels: f.pixels, palette: f.palette,
              opaque: transparent.map { t in f.pixels.map { $0 != t } })
}
func png(_ f: SequelMacFrame, _ path: URL) throws {
    let cg = CGImage(width: f.width, height: f.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: f.width*4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: CGDataProvider(data: Data(f.rgba) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let d = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d,cg,nil)
    guard CGImageDestinationFinalize(d) else { throw SequelDataError.invalid("Cannot write artwork proof.") }
}
@MainActor func save(_ name: String, _ f: SequelMacFrame, _ category: SequelMacCategory) throws {
    let mac = try SequelMacArtwork.reconstruct(f, category: category)
    try png(f, out.appendingPathComponent(name+"-pc.png"))
    try png(mac, out.appendingPathComponent(name+"-mac.png"))
    records.append(["name":name,"category":category.rawValue,"width":f.width,"height":f.height,"x":f.x,"y":f.y])
}
let tribes = ["CLASSIC","BEACH","CAVEMAN","CIRCUS","EGYPTIAN","HIGHLAND","MEDIEVAL","OUTDOOR","POLAR","SHADOW","SPACE","SPORTS"]
let bank = try Lemmings2Sprites(data: read(l2,"VLEMMS.DAT"))
let palette = try Lemmings2Style(data: read(l2,"STYLES/CLASSIC.DAT")).palette
let walker = try Lemmings2Walker(data: read(l2,"WALKER.DAT"))
for (i,f) in walker.frames.prefix(8).enumerated() { try save("l2-walker-\(i)",frame(f,palette),.sprite) }
for key in ["LM00","LM01","LM05","LM0E","LM19","LM26","LM20"] {
    for (i,f) in (bank.animations[key] ?? []).prefix(4).enumerated() {
        try save("l2-\(key)-\(i)",frame(f,palette),.sprite)
    }
}
var objectKinds = Set<String>()
for number in 0..<120 {
    let level = try Lemmings2Level(data: read(l2,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    guard [0,2,4,7,10].contains(level.style) else { continue }
    let style = try Lemmings2Style(data: read(l2,"STYLES/\(tribes[level.style]).DAT"))
    if number % 10 == 0 {
        let terrain = try Lemmings2Terrain(level: level, style: style)
        try save("l2-level-\(number)-terrain",frame(terrain.image),.lemmings2Terrain(tribe:level.style))
        for id in [style.tiles.count/3,style.tiles.count/2,style.tiles.count-1] {
            try save("l2-tile-\(level.style)-\(id)",.init(width:16,height:8,pixels:style.tiles[id],palette:style.palette),.lemmings2Terrain(tribe:level.style))
        }
    }
    let objects = try Lemmings2Objects(level: level, style: style)
    for p in objects.parts where [2,3,4,6,9,11].contains(p.type) && !p.frames.isEmpty {
        let key="l2-object-tribe\(level.style)-type\(p.type)"
        guard objectKinds.insert(key).inserted else { continue }
        for (i,f) in p.frames.prefix(3).enumerated() {
            try save(key+"-\(i)",frame(f,style.palette),p.type == 6 ? .liquid : .mechanical)
        }
    }
}
for styleNumber in 1...3 {
    let style = try Lemmings3Style(directory:l3.appendingPathComponent("STYLES"),number:styleNumber)
    let sprite = [1:4,2:10,3:5][styleNumber]!
    let prefix=String(format:"GRAPHICS/TRIBE%03d",sprite)
    let sprites=try Lemmings3Sprites(index:read(l3,prefix+".IND"),commands:read(l3,prefix+".CMP"))
    for id in [0,1,2,4,8,12] where sprites.animations.indices.contains(id) {
        let a=sprites.animations[id]
        for (i,f) in a.frames.prefix(4).enumerated() {
            try save("l3-sprite-\(styleNumber)-\(id)-\(i)",.init(width:a.width,height:a.height,pixels:f.pixels,palette:style.palette,opaque:f.opaque),.sprite)
        }
    }
    var chosen=0
    for o in style.permanent.objects.values.sorted(by:{$0.identifier<$1.identifier}) where o.frameCount>1 {
        for i in 0..<min(3,o.frameCount) {
            try save("l3-object-\(styleNumber)-\(o.identifier)-\(i)",frame(style.permanent.image(object:o.identifier,frame:i,palette:style.palette),transparent:255),.mechanical)
        }
        chosen+=1; if chosen==5 { break }
    }
    let number=(styleNumber-1)*100+1
    let level=try Lemmings3Level(data:read(l3,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    let perm=try Lemmings3Objects(data:read(l3,String(format:"LEVELS/PERM%03d.OBS",level.permanentObjectsReference)))
    let temp=try Lemmings3Objects(data:read(l3,String(format:"LEVELS/TEMP%03d.OBS",level.temporaryObjectsReference)))
    let scene=try Lemmings3Scene(level:level,style:style,permanent:perm,temporary:temp)
    try save("l3-level-\(number)",frame(scene.image),.lemmings3Terrain(style:styleNumber))
}
let referenceRoot = root.appendingPathComponent(".build/sequel-mac-artwork/references")
let classicRoot = root.appendingPathComponent("Content/lemming1.pc")
let classicLevel = try ClassicDataSet.detect(directory:classicRoot).campaign.levels[0].level
let classicGround = try ClassicGroundSet.load(style:classicLevel.groundStyle,from:classicRoot)
let classicRendered = try ClassicLevelRenderer.render(classicLevel,groundSet:classicGround)
let classicAssets = try ClassicMainDATAssets.load(from:classicRoot)
var classicSimulation = try ClassicDOSSimulation(level:classicLevel,renderedLevel:classicRendered,mainDATAssets:classicAssets)
for _ in 0..<110 { _ = classicSimulation.tick() }
let macRoot = CommandLine.arguments.count > 2 ? URL(fileURLWithPath:CommandLine.arguments[2])
    : root.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources/MacArtwork")
let originalMac = try ClassicMacArtwork(directory:macRoot.appendingPathComponent("lemmings"))
let classicMac = try ClassicMacScene(level:classicLevel,rendered:classicRendered,artwork:originalMac,groundSet:classicGround)
try png(.init(width:classicMac.width,height:classicMac.height,rgba:Array(classicMac.rgba(simulation:classicSimulation))),out.appendingPathComponent("original-mac-level.png"))
try png(.init(width:classicRendered.width,height:classicRendered.height,rgba:Array(ClassicSceneFrame.rgba(classicRendered,simulation:classicSimulation))),out.appendingPathComponent("original-dos-level.png"))
let referenceRecords = try JSONSerialization.jsonObject(with:read(referenceRoot,"manifest.json")) as! [[String:Any]]
let selectedReferences: [String:SequelMacCategory] = [
    "lemmings-sprite-walking-right-0":.sprite,"lemmings-sprite-building-right-0":.sprite,
    "lemmings-terrain-0-0":.organic,"ohno-terrain-1-0":.organic,
    "ohno-terrain-0-0":.architectural,"holiday-terrain-2-0":.organic,
    "lemmings-object-0-0-0":.mechanical,"lemmings-object-0-1-0":.mechanical,
    "lemmings-object-0-5-0":.liquid,"lemmings-object-0-4-0":.mechanical]
for r in referenceRecords {
    let name = r["name"] as! String
    guard let category = selectedReferences[name] else { continue }
    let d = r["dos"] as! [String:Any]
    let f = try SequelMacFrame(width:d["width"] as! Int,height:d["height"] as! Int,
        x:d["x"] as! Int,y:d["y"] as! Int,rgba:Array(read(referenceRoot,d["file"] as! String)))
    try save("ref-"+name,f,category)
}
try JSONSerialization.data(withJSONObject: records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"))
print("Wrote \(records.count) proof assets.")
