import Foundation
import CryptoKit
import NxlvKit

func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw SequelDataError.invalid(message) }
}
func rejects(_ operation: () throws -> Void) throws {
    do { try operation() } catch { return }
    throw SequelDataError.invalid("Invalid artwork was accepted.")
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent(".build/sequel-mac-artwork/complete")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
var inventory: [[String: Any]] = []
var categories: [String: Int] = [:]
var modified: [String: Int] = [:]
var cached = Set<String>()
func read(_ base: URL, _ path: String) throws -> Data { try Data(contentsOf: base.appendingPathComponent(path)) }
func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data: Data(bytes)).map { String(format:"%02x",$0) }.joined() }
func frame(_ f: Lemmings2SpriteFrame, _ palette: [UInt8]) throws -> SequelMacFrame {
    try .init(width:f.width,height:f.height,x:f.x,y:f.y,pixels:f.pixels,palette:palette,opaque:f.opaque)
}
func frame(_ f: SequelIndexedImage, transparent: UInt8? = nil) throws -> SequelMacFrame {
    try .init(width:f.width,height:f.height,pixels:f.pixels,palette:f.palette,
              opaque: transparent.map { t in f.pixels.map { $0 != t } })
}
@MainActor @discardableResult func check(_ name: String, _ source: SequelMacFrame,
                                       _ category: SequelMacCategory, store: Bool = true) throws -> SequelMacFrame {
    let before = digest(source.rgba)
    let result = try SequelMacArtwork.reconstruct(source, category:category)
    try require(result.width == source.width*2 && result.height == source.height*2,"Wrong dimensions: \(name)")
    try require(result.x == source.x*2 && result.y == source.y*2,"Wrong origin: \(name)")
    try require(before == digest(source.rgba),"Source mutated: \(name)")
    var changed = false
    for y in 0..<result.height { for x in 0..<result.width {
        let s = ((y/2)*source.width+x/2)*4, d = (y*result.width+x)*4
        try require(result.rgba[d+3] == source.rgba[s+3],"Opacity changed: \(name)")
        if result.rgba[d+3] == 0 {
            try require(result.rgba[d] == 0 && result.rgba[d+1] == 0 && result.rgba[d+2] == 0,"Transparent colour halo: \(name)")
        } else if result.rgba[d..<d+3] != source.rgba[s..<s+3] { changed = true }
    } }
    let hash = digest(result.rgba)
    if inventory.count % 197 == 0 {
        let repeated = try SequelMacArtwork.reconstruct(source,category:category)
        try require(repeated == result,"Nondeterministic reconstruction")
    }
    if store && cached.insert(hash).inserted {
        let path = out.appendingPathComponent(hash+".rgba")
        if !FileManager.default.fileExists(atPath:path.path) { try Data(result.rgba).write(to:path,options:.atomic) }
    }
    categories[category.rawValue,default:0] += 1
    if changed { modified[category.rawValue,default:0] += 1 }
    inventory.append(["asset":name,"category":category.rawValue,"width":result.width,"height":result.height,
        "x":result.x,"y":result.y,"sourceSHA256":before,"outputSHA256":hash,"changed":changed,"cached":store])
    return result
}

// Binary alpha, opaque black, odd dimensions and signed origins are independent.
let small = try SequelMacFrame(width:3,height:1,x:-7,y:3,
    rgba:[0,0,0,255, 255,0,255,0, 200,180,160,255])
let doubled = try check("synthetic-registration",small,.organic)
try require(doubled.width == 6 && doubled.height == 2 && doubled.x == -14 && doubled.y == 6,"Odd frame registration")
try rejects { _ = try SequelMacFrame(width:1,height:1,rgba:[0,0,0,127]) }
try rejects { _ = try SequelMacFrame(width:1,height:1,x:Int.min,rgba:[0,0,0,255]) }
try rejects { _ = try SequelMacArtwork.reconstruct(small,category:.organic,edits:[.init(x:2,y:0,red:1,green:2,blue:3)]) }
try rejects { _ = try SequelMacArtwork.reconstruct(small,category:.organic,edits:[.init(x:6,y:0,red:1,green:2,blue:3)]) }

let l2 = root.appendingPathComponent("Sources/Ports/Lemm2")
let l3 = root.appendingPathComponent("Sources/Ports/LEM3CD")
let bank = try Lemmings2Sprites(data:read(l2,"VLEMMS.DAT"))
let intern = try Lemmings2SpecialGraphics(data:read(l2,"INTERN.DAT"))
let walker = try Lemmings2Walker(data:read(l2,"WALKER.DAT"))
let front = try Lemmings2FrontEnd(root:l2)
let masks = try Lemmings2TerrainMasks(root:l2)
var styles: [Lemmings2Style] = []
for (tribe,name) in Lemmings2Campaign.styleNames.enumerated() {
    let style = try Lemmings2Style(data:read(l2,"STYLES/\(name).DAT"))
    styles.append(style)
    let category = SequelMacCategory.lemmings2Terrain(tribe:tribe)
    for (i,pixels) in style.tiles.enumerated() {
        try check("l2/\(name)/tile/\(i)",.init(width:16,height:8,pixels:pixels,palette:style.palette),category)
    }
    let index = Array(try style.container.requiredSection("L2BI"))
    for i in 0..<(Int(index[0]) | Int(index[1])<<8) {
        let liquid = style.objects.contains { $0.type == 6 && $0.components.contains { $0.graphics == i && $0.graphicsFlags & 0x20 == 0 } }
        for (f,pixels) in try style.animation(i).enumerated() {
            try check("l2/\(name)/object/\(i)/\(f)",frame(pixels,transparent:0),liquid ? .liquid : .mechanical)
        }
    }
    let special = try Lemmings2SpecialGraphics(data:read(l2,"STYLES/\(name).DAT"))
    for i in 0..<(try special.animationCount) {
        for (f,pixels) in try special.animation(i).enumerated() {
            try check("l2/\(name)/special/\(i)/\(f)",frame(pixels,style.palette),.mechanical)
        }
    }
    for (name,frames) in bank.animations.sorted(by:{$0.key<$1.key}) {
        for (i,f) in frames.enumerated() { try check("l2/tribe\(tribe)/\(name)/\(i)",frame(f,style.palette),.sprite) }
    }
    for (i,f) in walker.frames.enumerated() { try check("l2/tribe\(tribe)/walker/\(i)",frame(f,style.palette),.sprite) }
    for i in 0..<(try intern.animationCount) {
        for (f,pixels) in try intern.animation(i).enumerated() {
            try check("l2/tribe\(tribe)/intern/\(i)/\(f)",frame(pixels,style.palette),.mechanical)
        }
    }
    print("PASS L2 \(name): tiles, objects, lemmings, walker and effects")
}
for (name,bank) in front.banks.sorted(by:{$0.key<$1.key}) {
    for (p,palette) in bank.palettes.enumerated() {
        for (a,frames) in bank.sprites.enumerated() {
            for (f,image) in frames.enumerated() {
                try check("l2/frontend/\(name)/\(p)/\(a)/\(f)",frame(image,palette),.architectural)
            }
        }
    }
}
let uiPalette = Lemmings2Panel.palette(over:styles[0].palette)
for (name,pixels) in front.pictures.sorted(by:{$0.key<$1.key}) {
    try check("l2/screen/\(name)",.init(width:320,height:200,pixels:pixels,palette:front.banks["MENU"]!.palettes[0]),.architectural)
}
for (name,frames) in [("skill",front.panel.skills),("control",front.panel.controls)] {
    for (i,f) in frames.enumerated() { try check("l2/panel/\(name)/\(i)",frame(f,uiPalette),.architectural) }
}
for (i,glyph) in front.font.glyphs.enumerated() {
    try check("l2/font/\(i)",.init(width:16,height:11,pixels:glyph,palette:uiPalette,opaque:glyph.map{$0 != 0}),.architectural)
}

var levelCount = 0
for number in Array(0..<120)+[904,906,908,910] {
    let level = try Lemmings2Level(data:read(l2,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    let style = styles[level.style]
    let terrain = try Lemmings2Terrain(level:level,style:style)
    try check("l2/level/\(number)",frame(terrain.image),.lemmings2Terrain(tribe:level.style),store:false)
    // A rendered frame cannot mutate the engine or its 1x terrain masks.
    var game = try Lemmings2Runtime(level:level,style:style,masks:masks,
        practiceSkills:number >= 900 ? [.jumper,.runner,.builder,.basher,.digger,.climber,.floater,.roper] : nil)
    var control = game
    for _ in 0..<30 {
        game.step(); control.step()
        if game.tick % 10 == 0 {
            _ = try SequelMacArtwork.reconstruct(.init(width:game.configuration.width,height:game.configuration.height,
                pixels:game.pixels,palette:game.configuration.palette),category:.lemmings2Terrain(tribe:level.style))
        }
    }
    try require(game.pixels == control.pixels && game.solid == control.solid && game.tick == control.tick,
        "Rendering altered L2 gameplay")
    levelCount += 1
}
for styleNumber in 1...3 {
    let style = try Lemmings3Style(directory:l3.appendingPathComponent("STYLES"),number:styleNumber)
    for (name,bank) in [("perm",style.permanent),("temp",style.temporary)] {
        for o in bank.objects.values.sorted(by:{$0.identifier<$1.identifier}) where o.columns>0 && o.rows>0 {
            for f in 0..<o.frameCount {
                let image = try bank.image(object:o.identifier,frame:f,palette:style.palette)
                try check("l3/\(styleNumber)/\(name)/\(o.identifier)/\(f)",frame(image,transparent:255),
                          o.frameCount>1 ? .mechanical : .lemmings3Terrain(style:styleNumber))
            }
        }
    }
    for number in ((styleNumber-1)*100+1)...((styleNumber-1)*100+30) {
        let level = try Lemmings3Level(data:read(l3,String(format:"LEVELS/LEVEL%03d.DAT",number)))
        let perm = try Lemmings3Objects(data:read(l3,String(format:"LEVELS/PERM%03d.OBS",level.permanentObjectsReference)))
        let temp = try Lemmings3Objects(data:read(l3,String(format:"LEVELS/TEMP%03d.OBS",level.temporaryObjectsReference)))
        let scene = try Lemmings3Scene(level:level,style:style,permanent:perm,temporary:temp)
        try check("l3/level/\(number)",frame(scene.image),.lemmings3Terrain(style:styleNumber),store:false)
        var game = try Lemmings3Runtime(level:level,style:style,permanent:perm,temporary:temp)
        var control = game
        for _ in 0..<30 { game.step(); control.step() }
        _ = try SequelMacArtwork.reconstruct(frame(scene.image),category:.lemmings3Terrain(style:styleNumber))
        try require(game.terrainEdits == control.terrainEdits && game.tick == control.tick && game.saved == control.saved,
            "Rendering altered L3 gameplay")
        levelCount += 1
    }
    print("PASS L3 style \(styleNumber): both object banks and 30 levels")
}
let graphics = l3.appendingPathComponent("GRAPHICS")
for url in try FileManager.default.contentsOfDirectory(at:graphics,includingPropertiesForKeys:nil).sorted(by:{$0.path<$1.path}) where url.pathExtension == "IND" {
    let prefix = url.deletingPathExtension().lastPathComponent
    let sprites = try Lemmings3Sprites(index:read(graphics,prefix+".IND"),commands:read(graphics,prefix+".CMP"))
    let base = try Lemmings3Style(directory:l3.appendingPathComponent("STYLES"),number:1).palette
    let palette = try Lemmings3Sprites.palette(read(graphics,prefix+".PAL"),over:base)
    for (a,animation) in sprites.animations.enumerated() {
        for (f,image) in animation.frames.enumerated() {
            try check("l3/\(prefix)/\(a)/\(f)",.init(width:animation.width,height:animation.height,
                pixels:image.pixels,palette:palette,opaque:image.opaque),prefix.hasPrefix("TRIBE") ? .sprite : .mechanical)
        }
    }
}
try require(levelCount == 214,"Incomplete level coverage")
try require((modified["sprite"] ?? 0)>100 && (modified["organic"] ?? 0)>100,"Artwork is only nearest-neighbour enlargement")
let report: [String: Any] = ["revision":SequelMacArtwork.revision,"levels":levelCount,
    "frames":inventory.count,"uniqueCachedFrames":cached.count,"categories":categories,"modifiedFrames":modified,"assets":inventory]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"),options:.atomic)
print("PASS \(inventory.count) frames, \(cached.count) generated cache entries, \(levelCount) levels")
