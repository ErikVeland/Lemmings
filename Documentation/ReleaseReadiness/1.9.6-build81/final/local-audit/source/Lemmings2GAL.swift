import Foundation

/// Interpreter for the original three-byte GAL animation commands.
/// GAL is an animation data format. This does not execute DOS instructions.
public struct Lemmings2GAL {
    private struct Process {
        var pc = 6, state = 0, wait = 0, comparison = 0
        var registers = [Int](repeating:0,count:16)
        var stack: [Int] = []
    }
    private struct Bob {
        var visible = 0, type = 0, x = 0, y = 0, mode = 0
        var identifier = 0, frame = -1, palette = -1, colourOffset = 0
    }
    private let script: SequelBinary
    private let bank: Lemmings2FrontEnd.Bank
    private let font: Lemmings2FrontEndFont
    private var processes = [Process](repeating:Process(),count:32)
    private var bobs = [Bob](repeating:Bob(),count:32)
    private var order = [Int](repeating:-1,count:32)
    private var memory: [Int:Int] = [:]
    private var atomic = false
    private var background: [UInt8]
    private var savedBackground: [UInt8]
    private var textLayout: (x:Int,y:Int,width:Int,alignment:Int)?
    private var paletteTarget: [UInt8]
    private var paletteCount = 256
    private var fontColourOffset: UInt8 = 0
    private var displayOffset = 0
    private var viewport = Lemmings2Runtime.Rect(x:0,y:0,width:320,height:200)
    public private(set) var pixels: [UInt8]
    public private(set) var palette: [UInt8]
    public private(set) var interval = 1
    public private(set) var frameCount = 0
    public private(set) var soundSamples: [Int] = []
    public var isComplete: Bool { processes[0].state == 0 }
    public var frameDuration: Double { Double(max(1,interval))/70 }

    public init(script: Data, bank: Lemmings2FrontEnd.Bank, background: [UInt8], font: Lemmings2FrontEndFont, initialPalette: [UInt8]? = nil, initialMemory: [Int:Int] = [:]) throws {
        guard script.count >= 9, script.count <= 65536, background.count == 64000,
              !bank.palettes.isEmpty, initialPalette == nil || initialPalette?.count == 1024 else { throw SequelDataError.invalid("Invalid L2 animation scene.") }
        self.script = SequelBinary(script); self.bank = bank; self.font = font
        memory = initialMemory.mapValues { $0 & 65535 }
        self.background = background; savedBackground = background; pixels = background
        palette = initialPalette ?? [UInt8](repeating:0,count:1024)
        for index in 0..<256 { palette[index*4+3] = 255 }
        paletteTarget = palette
        processes[0].state = 4
    }
    /// Latch one click until the script's input process reads it.
    public mutating func requestContinue() {
        if processes[0].state == 2 || frameCount >= 70 { memory[0x27fe] = 1 }
    }

    private func signed(_ value: Int) -> Int { Int(Int16(bitPattern:UInt16(value & 65535))) }
    private func compare(_ a: Int, _ b: Int) -> Int { signed(a) == signed(b) ? 0 : signed(a) < signed(b) ? -1 : 1 }

    public mutating func step() throws {
        guard !isComplete else { return }
        soundSamples.removeAll(keepingCapacity:true)
        var budget = 20000
        repeat {
            for index in processes.indices {
                if processes[index].state == 1 {
                    processes[index].wait -= 1
                    if processes[index].wait <= 0 { processes[index].state = 4 }
                    continue
                }
                guard processes[index].state == 4 else { continue }
                repeat {
                    budget -= 1
                    guard budget >= 0 else { throw SequelDataError.invalid("L2 animation exceeded its command limit.") }
                    try execute(index)
                } while atomic
            }
            if isComplete { return }
        } while interval == 0
        pixels = background
        for index in order where index >= 0 {
            var bob = bobs[index]
            try draw(&bob)
            bobs[index] = bob
        }
        if displayOffset > 0 { pixels = Array(pixels.dropFirst(min(64000,displayOffset)))+Array(repeating:0,count:min(64000,displayOffset)) }
        frameCount += 1
    }

    private mutating func execute(_ index: Int) throws {
        var process = processes[index], bob = bobs[index]
        let bytes = try script.slice(process.pc,3)
        let op = Int(bytes[0]), a = Int(bytes[1]), b = Int(bytes[2]), value = a | b << 8
        let kind = op >> 4, register = op & 15, left = a >> 4, right = a & 15
        switch kind {
        case 0:
            process.registers[register] = memory[value] ?? 0
            if value == 0x27fe { memory[value] = 0 }
        case 1: memory[value] = process.registers[register]
        case 2: break
        case 3: process.registers[register] = value
        case 4: process.comparison = compare(process.registers[register],process.registers[left])
        case 5: process.registers[register] = (process.registers[left]+process.registers[right])&65535
        case 6: process.registers[register] = (process.registers[left]-process.registers[right])&65535
        case 7: process.comparison = compare(process.registers[register],value)
        case 8: atomic = true
        case 9: atomic = false
        case 10: process.registers[register] = (process.registers[left]*process.registers[right])&65535
        case 11:
            let divisor = signed(process.registers[right])
            guard divisor != 0 else { throw SequelDataError.invalid("L2 animation divided by zero.") }
            process.registers[register] = (signed(process.registers[left])/divisor)&65535
        case 12:
            var end = process.pc+1
            while end < script.count && script.bytes[end] != 0 { end += 1 }
            guard end < script.count else { throw SequelDataError.invalid("Unterminated L2 animation callback.") }
            let callback = String(decoding:script.bytes[(process.pc+1)..<end],as:UTF8.self)
            if callback == "introplayfx" {
                if let sample = memory[0], (0..<79).contains(sample) { soundSamples.append(sample) }
            } else if callback == "fanfare" {
                let medal = memory[0] ?? 0
                guard (0..<4).contains(medal) else { throw SequelDataError.invalid("Invalid L2 award medal.") }
                soundSamples.append([50,53,52,51][medal])
            } else { throw SequelDataError.invalid("Unsupported L2 animation callback.") }
            process.pc = end
        case 15:
            switch register {
            case 0: process.pc += signed(value)
            case 1:
                guard process.stack.count < 5 else { throw SequelDataError.invalid("L2 animation call stack overflow.") }
                process.stack.append(process.pc); process.pc += signed(value)
            case 2: if process.comparison == 0 { process.pc += signed(value) }
            case 3: if process.comparison < 0 { process.pc += signed(value) }
            case 4: if process.comparison > 0 { process.pc += signed(value) }
            case 5:
                guard let child = processes.indices.first(where:{$0 > index && processes[$0].state == 0}) else {
                    throw SequelDataError.invalid("Too many L2 animation processes.")
                }
                processes[child].pc = try script.u16(process.pc+signed(value)+3)
                processes[child].state = 4
            case 6:
                guard a < 32, b < 32 else { throw SequelDataError.invalid("Invalid L2 animation drawing order.") }
                if let old = order.firstIndex(of:a) { order[old] = -1 }
                if order[b] != -1 {
                    guard let hole = (b..<32).first(where:{order[$0] == -1}) else {
                        throw SequelDataError.invalid("L2 animation drawing order overflow.")
                    }
                    for target in stride(from:hole,to:b,by:-1) { order[target] = order[target-1] }
                }
                order[b] = a
            case 7: if process.comparison != 0 { process.pc += signed(value) }
            case 8: bob.type = 3; bob.palette = value; bob.visible = 1
            case 9: bob.type = 1; bob.identifier = value; bob.frame = -1; bob.visible = 1
            case 10:
                viewport = .init(x:signed(process.registers[left]),y:signed(process.registers[right]),
                    width:process.registers[b >> 4],height:process.registers[b & 15])
            case 11: break // Original mouse confinement; the native app owns its pointer.
            case 12:
                let x = signed(process.registers[left]), y = signed(process.registers[right])
                let width = process.registers[b >> 4], height = process.registers[b & 15]
                for py in max(0,min(200,y))..<max(0,min(200,y+height)) {
                    for px in max(0,min(320,x))..<max(0,min(320,x+width)) {
                        let offset = py*320+px
                        background[offset] = savedBackground[offset]; pixels[offset] = savedBackground[offset]
                    }
                }
            case 13:
                textLayout = (signed(process.registers[left]),signed(process.registers[right]),
                              process.registers[b >> 4],process.registers[b & 15])
            case 15:
                if (2...7).contains(a >> 4) {
                    let lhs = process.registers[b >> 4], rhs = process.registers[b & 15]
                    let result: Int
                    switch a >> 4 {
                    case 2: result = lhs ^ rhs
                    case 3: result = lhs & rhs
                    case 4: result = lhs | rhs
                    case 5: result = lhs << (b & 15)
                    case 6: result = lhs >> (b & 15)
                    default: result = -lhs
                    }
                    process.registers[a & 15] = result & 65535
                } else {
                    switch a {
                    case 0xf0: bob.colourOffset = b
                    case 0xf1: memory[process.registers[b & 15]] = process.registers[b >> 4]
                    case 0xf2: paletteCount = b == 0 ? 256 : b
                    case 0xf3: fontColourOffset = UInt8(b)
                    case 0xf4: process.wait = b; process.state = 1
                    case 0xf5: bob.type = 0; bob.identifier = b; bob.frame = -1; bob.visible = 1
                    case 0xf9:
                        guard b < 32 else { throw SequelDataError.invalid("Invalid L2 animation process.") }
                        if b == index && process.state == 2 { process.state = 4 }
                        else if processes[b].state == 2 { processes[b].state = 4 }
                    case 0xfa:
                        guard b < 32 else { throw SequelDataError.invalid("Invalid L2 animation process.") }
                        if b == index { process.state = 0 } else { processes[b].state = 0 }
                    case 0xfb: interval = b
                    case 0xfc: process.registers[b >> 4] = memory[process.registers[b & 15]] ?? 0
                    case 0xfd: displayOffset = b*4
                    case 0xff:
                        switch b {
                        case 0x10...0x1f:
                            bob.type = 0; bob.identifier = process.registers[b&15]; bob.frame = -1; bob.visible = 1
                        case 0x20...0x2f:
                            bob.type = 1; bob.identifier = process.registers[b&15]; bob.frame = -1; bob.visible = 1
                        case 0x30...0x3f: bob.frame = process.registers[b&15]
                        case 0x50...0x5f: bob.type = 3; bob.palette = process.registers[b&15]; bob.visible = 1
                        case 0x60,0x61: break // VGA dirty-region restoration is handled by the canvas.
                        case 0xf0: paletteTarget = [UInt8](repeating:0,count:1024)
                        case 0xf2: bob.mode = 3
                        case 0xf3: try draw(&bob)
                        case 0xf4: break
                        case 0xf5: process.state = 2
                        case 0xf6:
                            guard let caller = process.stack.popLast() else { throw SequelDataError.invalid("L2 animation return without a call.") }
                            process.pc = caller
                        case 0xf7: bob.mode = 2
                        case 0xf8: break
                        case 0xf9: bob.mode = 0
                        case 0xfa: bob.mode = 1
                        case 0xfb: bob.frame = -1
                        case 0xfc: if bob.visible == 1 { bob.visible = 2 }
                        case 0xfd: if bob.visible == 2 { bob.visible = 1 }
                        case 0xfe: bob.visible = 0
                        case 0xff: process.state = 0; atomic = false
                        default: throw SequelDataError.invalid("Unsupported L2 animation register command.")
                        }
                    default: throw SequelDataError.invalid("Unsupported L2 animation extended command.")
                    }
                }
            default: throw SequelDataError.invalid("Unsupported L2 animation scene command.")
            }
        default: throw SequelDataError.invalid("Unsupported L2 animation command.")
        }
        if bob.visible != 0 && bob.type != 3 {
            bob.x = signed(process.registers[14]); bob.y = signed(process.registers[15])
        }
        process.pc += 3
        processes[index] = process; bobs[index] = bob
    }

    private mutating func draw(_ bob: inout Bob) throws {
        guard bob.visible != 0 else { return }
        if bob.type == 3 {
            if bob.palette >= 0 {
                guard bank.palettes.indices.contains(bob.palette) else { throw SequelDataError.invalid("Invalid L2 animation palette.") }
                paletteTarget = bank.palettes[bob.palette]; bob.palette = -1
            }
            var changed = false
            for index in 0..<min(256,paletteCount) { for channel in 0..<3 {
                let offset = index*4+channel
                let current = (Int(palette[offset])*63+127)/255, target = (Int(paletteTarget[offset])*63+127)/255
                let next = current+max(-2,min(2,target-current))
                palette[offset] = UInt8(next*255/63)
                changed = changed || next != target
            } }
            if !changed { bob.visible = 0 }
            return
        }
        if bob.type == 0 {
            guard bank.sprites.indices.contains(bob.identifier), !bank.sprites[bob.identifier].isEmpty else {
                throw SequelDataError.invalid("Invalid L2 animation sprite.")
            }
            let frames = bank.sprites[bob.identifier]
            if bob.frame < 0 { bob.frame = 0 }
            else if bob.visible == 1 { bob.frame = (bob.frame+1)%frames.count }
            let frame = frames[bob.frame]
            paint(frame.pixels.map{ $0 &+ UInt8(bob.colourOffset) },opaque:frame.opaque,width:frame.width,height:frame.height,
                  x:bob.x+frame.x,y:bob.y+frame.y,mode:bob.mode)
        } else if bob.type == 1 {
            guard bank.strings.indices.contains(bob.identifier) else { throw SequelDataError.invalid("Invalid L2 animation text.") }
            var lines: [String] = []
            for paragraph in bank.strings[bob.identifier].split(separator:"\r",omittingEmptySubsequences:false) {
                guard let layout = textLayout, layout.width > 0 else { lines.append(String(paragraph)); continue }
                var line = ""
                for word in paragraph.split(separator:" ") {
                    let proposed = line.isEmpty ? String(word) : line+" "+word
                    if !line.isEmpty && font.width(proposed) > layout.width { lines.append(line); line = String(word) }
                    else { line = proposed }
                }
                lines.append(line)
            }
            for (row,line) in lines.enumerated() {
                var x = bob.x+(textLayout?.x ?? 0)
                if let layout = textLayout {
                    if layout.alignment == 5 { x += (layout.width-font.width(line))/2 }
                    else if layout.alignment == 6 { x += layout.width-font.width(line) }
                }
                for byte in line.utf8 where (32..<123).contains(byte) {
                    let glyph = font.glyphs[Int(byte)-32]
                    paint(glyph.map{$0 &+ fontColourOffset},opaque:glyph.map{$0 != 0},width:16,height:11,
                          x:x,y:bob.y+(textLayout?.y ?? 0)+row*12,mode:bob.mode)
                    x += font.advances[Int(byte)-32]
                }
            }
        }
    }
    private mutating func paint(_ source:[UInt8],opaque:[Bool]?,width:Int,height:Int,x:Int,y:Int,mode:Int) {
        let clip = mode == 2 ? viewport : .init(x:0,y:0,width:320,height:200)
        for row in 0..<height { for column in 0..<width {
            let sourceIndex = row*width+column
            if let opaque, !opaque[sourceIndex] { continue }
            let px = x+column+(mode == 2 ? viewport.x : 0), py = y+row+(mode == 2 ? viewport.y : 0)
            guard px >= 0, py >= 0, px < 320, py < 200, clip.contains(px,py) else { continue }
            let index = py*320+px
            pixels[index] = source[sourceIndex]
            if mode == 1 || mode == 3 { background[index] = source[sourceIndex] }
            if mode == 1 { savedBackground[index] = source[sourceIndex] }
        } }
    }
}
