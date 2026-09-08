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
@MainActor func save(_ name: String, _ f: SequelMacFrame, _ category: SequelMacCategory, reconstructed: SequelMacFrame? = nil) throws {
    let mac = try reconstructed ?? SequelMacArtwork.reconstruct(f, category: category)
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
@MainActor func saveObject(_ name: String, parts: [Lemmings2Objects.Part], palette: [UInt8], category: SequelMacCategory,
                          backdrop: SequelMacFrame? = nil, terrainCategory: SequelMacCategory = .organic) throws {
    let extents = parts.flatMap { p in p.frames.map { f in (p.x+f.x,p.y+f.y,f.width,f.height) } }
    guard var left = extents.map({$0.0}).min(), var top = extents.map({$0.1}).min(),
          var right = extents.map({$0.0+$0.2}).max(), var bottom = extents.map({$0.1+$0.3}).max() else { return }
    // Some traps animate only their eyes; their body is authored as terrain.
    // Include that body in the proof, preserving the real component placement.
    if backdrop != nil { left -= 24; top -= 24; right += 24; bottom += 24 }
    let w = right-left, h = bottom-top
    let highBackdrop = try backdrop.map { try SequelMacArtwork.reconstruct($0,category:terrainCategory) }
    func backdropPixels(_ f: SequelMacFrame?, scale: Int) -> [UInt8] {
        var pixels = [UInt8](repeating:0,count:w*h*scale*scale*4)
        guard let f else { return pixels }
        for row in 0..<(h*scale) { for col in 0..<(w*scale) {
            let x = left*scale+col, y = top*scale+row
            guard x >= 0, x < f.width, y >= 0, y < f.height else { continue }
            let s = (y*f.width+x)*4, d = (row*w*scale+col)*4
            pixels.replaceSubrange(d..<d+4,with:f.rgba[s..<s+4])
        } }
        return pixels
    }
    let background = backdropPixels(backdrop,scale:1), highBackground = backdropPixels(highBackdrop,scale:2)
    func paste(_ f: SequelMacFrame, into canvas: inout [UInt8], width: Int, x: Int, y: Int) {
        for row in 0..<f.height { for col in 0..<f.width {
            let s = (row*f.width+col)*4
            if f.rgba[s+3] != 0 {
                let d = ((y+row)*width+x+col)*4
                canvas.replaceSubrange(d..<d+4,with:f.rgba[s..<s+4])
            }
        } }
    }
    let count = parts.map({$0.frames.count}).max() ?? 0
    let phases = Set(Array(0..<min(3,count)) + [count/2,max(0,count-1)]).sorted()
    for phase in phases {
        var pc = background, mac = highBackground
        for p in parts {
            let f = p.frames[phase % p.frames.count], source = try frame(f,palette)
            let upgraded = try SequelMacArtwork.reconstruct(source,category:category)
            paste(source,into:&pc,width:w,x:p.x+f.x-left,y:p.y+f.y-top)
            paste(upgraded,into:&mac,width:w*2,x:(p.x+f.x-left)*2,y:(p.y+f.y-top)*2)
        }
        try save(name+"-\(phase)",.init(width:w,height:h,x:left,y:top,rgba:pc),category,
                 reconstructed:.init(width:w*2,height:h*2,x:left*2,y:top*2,rgba:mac))
    }
}
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
        try saveObject(key,parts:objects.parts.filter {$0.objectIndex == p.objectIndex && !$0.frames.isEmpty},
                       palette:style.palette,category:p.type == 6 ? .liquid : .mechanical,
                       backdrop:p.type == 9 ? frame(Lemmings2Terrain(level:level,style:style).image) : nil,
                       terrainCategory:.lemmings2Terrain(tribe:level.style))
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
    for o in style.permanent.objects.values.sorted(by:{$0.identifier<$1.identifier}) where o.flags == 0x4001 && o.frameCount>0 {
        for i in 0..<min(3,o.frameCount) {
            try save("l3-liquid-hazard-\(styleNumber)-\(o.identifier)-\(i)",frame(style.permanent.image(object:o.identifier,frame:i,palette:style.palette),transparent:255),.liquid)
        }
    }
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
var classicPixels = Array(classicMac.rgba(simulation:classicSimulation))
for lem in classicSimulation.lemmings where lem.isActive && (lem.action == .walking || lem.action == .falling) {
    let pose: ClassicLemmingPose = lem.action == .walking ? .walking : .falling
    let left = lem.direction == .left
    guard let f = originalMac.lemming(pose:pose,left:left,tick:lem.animationFrame),
          let a = classicAssets.animation(for:pose,direction:left ? .left : .right) else { continue }
    let ox = (lem.foot.x+a.offsetX)*2+f.x, oy = (lem.foot.y+a.offsetY)*2+f.y
    for y in 0..<f.height { for x in 0..<f.width {
        let px = ox+x, py = oy+y, s = (y*f.width+x)*4
        guard px>=0,py>=0,px<classicMac.width,py<classicMac.height,f.rgba[s+3] != 0 else { continue }
        let d = (py*classicMac.width+px)*4
        classicPixels.replaceSubrange(d..<d+4,with:f.rgba[s..<s+4])
    } }
}
try png(.init(width:classicMac.width,height:classicMac.height,rgba:classicPixels),out.appendingPathComponent("original-mac-level.png"))
let viewX = min(classicRendered.width-320,max(0,classicLevel.startX))*2
let viewport = (0..<320).flatMap { y in Array(classicPixels[(y*classicMac.width+viewX)*4..<(y*classicMac.width+viewX+640)*4]) }
try png(.init(width:640,height:320,rgba:viewport),out.appendingPathComponent("original-mac-viewport.png"))
try png(.init(width:classicRendered.width,height:classicRendered.height,rgba:Array(ClassicSceneFrame.rgba(classicRendered,simulation:classicSimulation))),out.appendingPathComponent("original-dos-level.png"))
let referenceRecords = try JSONSerialization.jsonObject(with:read(referenceRoot,"manifest.json")) as! [[String:Any]]
let selectedReferences: [String:SequelMacCategory] = [
    "lemmings-sprite-walking-right-0":.sprite,"lemmings-sprite-building-right-0":.sprite,
    "lemmings-terrain-0-0":.organic,"ohno-terrain-1-0":.organic,
    "ohno-terrain-0-0":.architectural,"holiday-terrain-2-0":.organic,
    "lemmings-object-0-0-0":.mechanical,"lemmings-object-0-1-0":.mechanical,
    "lemmings-object-0-5-0":.liquid,"lemmings-object-0-6-0":.mechanical]
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
