
// Appended to the two canvas source files by the runner to inspect real views.
import CryptoKit

let app = NSApplication.shared
let sourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let shotRoot = sourceRoot.appendingPathComponent(".build/sequel-mac-artwork/levels")
try FileManager.default.createDirectory(at:shotRoot,withIntermediateDirectories:true)
let previousPreference = UserDefaults.standard.object(forKey:SequelArtworkPreference.key)
defer {
    if let previousPreference { UserDefaults.standard.set(previousPreference,forKey:SequelArtworkPreference.key) }
    else { UserDefaults.standard.removeObject(forKey:SequelArtworkPreference.key) }
}
func readAsset(_ base: URL, _ path: String) throws -> Data { try Data(contentsOf:base.appendingPathComponent(path)) }
@MainActor func shot(_ view: NSView, _ name: String) throws -> Data {
    view.needsDisplay = true
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else {
        throw SequelDataError.invalid("Cannot render the sequel canvas.")
    }
    view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let png = bitmap.representation(using:.png,properties:[:]) else {
        throw SequelDataError.invalid("Cannot encode the sequel canvas.")
    }
    try png.write(to:shotRoot.appendingPathComponent(name+".png"))
    return png
}
func assertArtwork(_ condition: Bool, _ message: String) throws {
    if !condition { throw SequelDataError.invalid(message) }
}
let l2root = sourceRoot.appendingPathComponent("Sources/Ports/Lemm2")
let l2sprites = try Lemmings2Sprites(data:readAsset(l2root,"VLEMMS.DAT"))
let l2intern = try Lemmings2SpecialGraphics(data:readAsset(l2root,"INTERN.DAT"))
let l2masks = try Lemmings2TerrainMasks(root:l2root)
let l2explosion = try Lemmings2Explosion(data:readAsset(l2root,"EXPLOSION.DAT"))
let l2walker = try Lemmings2Walker(data:readAsset(l2root,"WALKER.DAT"))
let l2front = try Lemmings2FrontEnd(root:l2root)
for number in [0,20,40,70,100] {
    let level = try Lemmings2Level(data:readAsset(l2root,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    let style = try Lemmings2Style(data:readAsset(l2root,"STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT"))
    var game = try Lemmings2Runtime(level:level,style:style,masks:l2masks)
    for _ in 0..<110 { game.step() }
    let view = Lemmings2Canvas(frame:NSRect(x:0,y:0,width:640,height:480))
    let window = NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false)
    window.contentView = view
    SequelArtworkPreference.setEnabled(false)
    try view.load(level:level,style:style,sprites:l2sprites,intern:l2intern,explosion:l2explosion,walker:l2walker)
    view.update(game)
    let panel = try l2front.panel.render(skills:game.configuration.skills.map(\.rawValue),supplies:game.supplies,
        selected:0,saved:game.saved,remaining:game.lemmings.filter(\.active).count,seconds:game.remainingSeconds,
        label:"WALKER",palette:Lemmings2Panel.palette(over:style.palette))
    view.setPanel(panel)
    let original = try shot(view,"l2-\(number)-pc")
    SequelArtworkPreference.setEnabled(true)
    try view.refreshArtwork(); view.setPanel(panel)
    let upgraded = try shot(view,"l2-\(number)-mac")
    try assertArtwork(original != upgraded,"L2 artwork setting does not affect the live canvas")
    SequelArtworkPreference.setEnabled(false)
    try view.refreshArtwork(); view.setPanel(panel)
    let restored = try shot(view,"l2-\(number)-restored")
    try assertArtwork(original == restored,"L2 artwork toggle changed camera, registration or game state")
    window.contentView = nil
    print("PASS L2 live canvas \(number), 110 ticks, original/2x/toggle restoration")
}
let l3root = sourceRoot.appendingPathComponent("Sources/Ports/LEM3CD")
for number in [1,101,201] {
    let level = try Lemmings3Level(data:readAsset(l3root,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    let style = try Lemmings3Style(directory:l3root.appendingPathComponent("STYLES"),number:level.style)
    let perm = try Lemmings3Objects(data:readAsset(l3root,String(format:"LEVELS/PERM%03d.OBS",level.permanentObjectsReference)))
    let temp = try Lemmings3Objects(data:readAsset(l3root,String(format:"LEVELS/TEMP%03d.OBS",level.temporaryObjectsReference)))
    let prefix = String(format:"GRAPHICS/TRIBE%03d",level.lemmingStyle)
    let sprites = try Lemmings3Sprites(index:readAsset(l3root,prefix+".IND"),commands:readAsset(l3root,prefix+".CMP"))
    let scene = try Lemmings3Scene(level:level,style:style,permanent:perm,temporary:temp)
    var game = try Lemmings3Runtime(level:level,style:style,permanent:perm,temporary:temp)
    for _ in 0..<110 { game.step() }
    let view = Lemmings3Canvas(frame:NSRect(x:0,y:0,width:640,height:320))
    let window = NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false)
    window.contentView = view
    SequelArtworkPreference.setEnabled(false)
    try view.load(scene:scene,style:style,permanent:perm,temporary:temp,sprites:sprites,root:l3root,terrainStyle:level.style)
    view.resetCamera(level); view.game = game
    let original = try shot(view,"l3-\(number)-pc")
    SequelArtworkPreference.setEnabled(true); try view.refreshArtwork()
    let upgraded = try shot(view,"l3-\(number)-mac")
    try assertArtwork(original != upgraded,"L3 artwork setting does not affect the live canvas")
    SequelArtworkPreference.setEnabled(false); try view.refreshArtwork()
    let restored = try shot(view,"l3-\(number)-restored")
    try assertArtwork(original == restored,"L3 artwork toggle changed camera, registration or game state")
    window.contentView = nil
    print("PASS L3 live canvas \(number), 110 ticks, original/2x/toggle restoration")
}
