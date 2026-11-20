import CoreGraphics
import Foundation
import ImageIO
@testable import NxlvKit

struct Failure: Error { let message: String }
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw Failure(message: message) }
}
func rejects(_ body: () throws -> Void) throws {
    do { try body() } catch { return }
    throw Failure(message: "Malformed interface assets passed validation.")
}
func colour(_ frame: LixInterfaceArtwork.Frame, _ x: Int, _ y: Int) -> [UInt8] {
    let offset = (y * frame.width + x) * 4
    return Array(frame.rgba[offset..<(offset + 4)])
}
func write(_ bytes: [UInt8], width: Int, height: Int, to url: URL) throws {
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    try check(CGImageDestinationFinalize(destination), "Write interface capture")
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
do {
    let artwork = try LixInterfaceArtwork(directory: root)
    let play = artwork.control(.play)!, pause = artwork.control(.pause)!, help = artwork.control(.help)!
    try check(play.width == 20 && play.height == 20 && pause.width == 34 && pause.height == 60,
              "Source control dimensions exclude grid borders")
    try check(help.width == 40 && help.height == 30, "Help uses the actual source question mark")
    let bigSheet = try LixSceneArtwork.decode(Data(contentsOf: root.appendingPathComponent("assets/data/images/gamebigbuttons/1.png")))
    let sourceHelp = try bigSheet.crop(x: 42, y: 1, width: 40, height: 30)
    let white = stride(from: 0, to: sourceHelp.rgba.count, by: 4).first {
        Array(sourceHelp.rgba[$0..<($0 + 4)]) == [255, 255, 255, 255]
    }!
    try check(colour(help, white / 4 % 40, white / 4 / 40) == [199, 211, 227, 255],
              "Source white maps through the upstream normal GUI palette")
    try check(artwork.control(.menu) == nil, "A missing menu icon stays a text action")
    try check(artwork.skill(.faller) == nil, "Unassignable and absent skills stay explicit")
    let activities: [LixArtwork.Activity] = [.walker, .runner, .climber, .floater, .imploder, .exploder,
        .blocker, .builder, .platformer, .basher, .miner, .digger, .jumper, .batter, .cuber]
    for activity in activities {
        let on = artwork.skill(activity)!, off = artwork.skill(activity, enabled: false)!
        try check(on.width == 32 && on.height == 32 && on.rgba != off.rgba,
                  "Every assignable skill uses its authored colour and disabled rows")
        for frame in [on, off] {
            for index in stride(from: 0, to: frame.rgba.count, by: 4) where frame.rgba[index + 3] != 0 {
                try check(Array(frame.rgba[index..<(index + 3)]) != [255, 0, 255], "No visible magenta separators")
                try check(Array(frame.rgba[index..<(index + 3)]) != [0, 0, 0], "Source black becomes transparent")
            }
        }
    }
    let nuke = artwork.control(.nuke)!, selectedNuke = artwork.control(.nuke, state: .selected)!
    try check(nuke.rgba != selectedNuke.rgba, "Active nuke keeps the actual yellow source state")
    try check(artwork.checkbox(checked: false)!.rgba != artwork.checkbox(checked: true)!.rgba,
              "Checkbox uses the authored tick")
    let normal = artwork.button(width: 44, height: 34)!
    let selected = artwork.button(width: 44, height: 34, state: .selected)!
    let pressed = artwork.button(width: 44, height: 34, state: .pressed)!
    try check(colour(normal, 0, 0)[0] > colour(normal, 43, 33)[0], "Normal backing uses the upstream raised bevel")
    try check(colour(selected, 0, 0)[0] < colour(selected, 43, 33)[0], "Selected backing uses the upstream inset bevel")
    try check(colour(normal, 0, 33) == colour(normal, 22, 17), "Mixed bevel corner uses the middle source colour")
    try check(selected.rgba != pressed.rgba, "Pressed and selected have distinct stone brightness")
    for state in LixInterfaceArtwork.State.allCases {
        for size in [(20, 20), (28, 44), (44, 34), (320, 48)] {
            let backing = artwork.button(width: size.0, height: size.1, state: state)!
            for offset in stride(from: 0, to: backing.rgba.count, by: 4) {
                let green = backing.rgba[offset + 1], blue = backing.rgba[offset + 2]
                try check(green >= blue, "Button backgrounds must not use the pale blue Lix palette")
                try check(backing.rgba[offset + 3] == (state == .disabled ? 112 : 255),
                          "Stone backing preserves disabled opacity")
            }
            let middle = colour(backing, size.0 / 2, size.1 / 2)
            try check(middle[0] < 90 && middle[1] < 90 && middle[2] < 90,
                      "Button faces stay dark behind bitmap labels")
        }
    }
    try check(artwork.button(width: Int.max, height: 1) == nil && artwork.button(width: 10, height: 10, border: Int.max) == nil,
              "Unbounded backing geometry is rejected before arithmetic")
    for state in LixInterfaceArtwork.State.allCases {
        for control in LixInterfaceArtwork.Control.allCases {
            guard let frame = artwork.control(control, state: state) else { continue }
            try check(frame.rgba.count == frame.width * frame.height * 4, "Every state has consistent dimensions")
        }
    }
    try rejects {
        _ = try LixInterfaceArtwork(read: { name in
            name == "gamebigbuttons/1.png" ? Data([0, 1, 2])
                : try Data(contentsOf: root.appendingPathComponent("assets/data/images/" + name))
        })
    }
    try rejects {
        _ = try LixInterfaceArtwork(read: { _ in try Data(contentsOf: root.appendingPathComponent("assets/data/images/lixrecol.png")) })
    }
    let linked = output.appendingPathComponent("linked-interface-pack")
    try? FileManager.default.removeItem(at: linked)
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: root)
    try rejects { _ = try LixInterfaceArtwork(directory: linked) }
    try FileManager.default.removeItem(at: linked)

    let controls: [LixInterfaceArtwork.Control] = [.play, .pause, .stepBackward, .stepForward, .rewind,
        .fastForward, .turbo, .restart, .nuke, .save, .load, .help, .undo, .rateDecrease, .rateIncrease]
    let cellWidth = 60, cellHeight = 80, width = cellWidth * controls.count, height = cellHeight * 4
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    func draw(_ frame: LixInterfaceArtwork.Frame, atX x: Int, y: Int) {
        for row in 0..<frame.height { for column in 0..<frame.width {
            let source = (row * frame.width + column) * 4
            guard frame.rgba[source + 3] != 0 else { continue }
            let target = ((y + row) * width + x + column) * 4
            pixels.replaceSubrange(target..<(target + 4), with: frame.rgba[source..<(source + 4)])
        } }
    }
    for (row, state) in LixInterfaceArtwork.State.allCases.enumerated() {
        for (column, control) in controls.enumerated() {
            let background = artwork.button(width: 56, height: 76, state: state)!
            draw(background, atX: column * cellWidth + 2, y: row * cellHeight + 2)
            let frame = artwork.control(control, state: state)!
            draw(frame, atX: column * cellWidth + (cellWidth - frame.width) / 2,
                 y: row * cellHeight + (cellHeight - frame.height) / 2)
        }
    }
    try write(pixels, width: width, height: height, to: output.appendingPathComponent("lix-interface-states.png"))
    let skillWidth = activities.count * 40, skillHeight = 80
    var skillPixels = [UInt8](repeating: 0, count: skillWidth * skillHeight * 4)
    for row in 0..<2 { for (column, activity) in activities.enumerated() {
        let frame = artwork.skill(activity, enabled: row == 0)!
        for y in 0..<frame.height { for x in 0..<frame.width {
            let source = (y * frame.width + x) * 4
            let target = ((row * 40 + y + 4) * skillWidth + column * 40 + x + 4) * 4
            skillPixels.replaceSubrange(target..<(target + 4), with: frame.rgba[source..<(source + 4)])
        } }
    } }
    try write(skillPixels, width: skillWidth, height: skillHeight, to: output.appendingPathComponent("lix-interface-skills.png"))
    print("PASS authored skill/control frames, selected and disabled states, source GUI palette, button backing, bounds and malformed-input rejection")
} catch { print("FAIL \(error)"); exit(1) }
