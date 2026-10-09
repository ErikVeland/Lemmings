import Foundation

/// Rendering categories inferred from the original Macintosh pixel artwork.
public enum SequelMacCategory: String, CaseIterable, Codable, Sendable {
    case sprite, lemmings2Walker, organic, architectural, mechanical, liquid

    public static func lemmings2Terrain(tribe: Int) -> Self {
        [1, 2, 5, 7, 8].contains(tribe) ? .organic : .architectural
    }
    public static func lemmings3Terrain(style: Int) -> Self {
        style == 1 ? .organic : .architectural
    }
}

/// A visual frame. Its origin is in the same pixel units as its dimensions.
/// No collision, animation duration or placement records enter this type.
public struct SequelMacFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let x: Int
    public let y: Int
    public let rgba: [UInt8]
    /// Keep the style palette fixed when destructible terrain loses a colour.
    public let sourcePalette: [UInt8]?

    public init(width: Int, height: Int, x: Int = 0, y: Int = 0, rgba: [UInt8], sourcePalette: [UInt8]? = nil) throws {
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              width * height <= 16 * 1024 * 1024, rgba.count == width * height * 4,
              (-65536...65536).contains(x), (-65536...65536).contains(y),
              sourcePalette == nil || sourcePalette?.count == 1024 else {
            throw SequelDataError.invalid("Invalid sequel artwork frame.")
        }
        guard stride(from: 3, to: rgba.count, by: 4).allSatisfy({ rgba[$0] == 0 || rgba[$0] == 255 }) else {
            throw SequelDataError.invalid("Sequel artwork requires binary transparency.")
        }
        self.width = width; self.height = height; self.x = x; self.y = y; self.rgba = rgba
        self.sourcePalette = sourcePalette
    }

    public init(width: Int, height: Int, x: Int = 0, y: Int = 0,
                pixels: [UInt8], palette: [UInt8], opaque: [Bool]? = nil) throws {
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              pixels.count == width * height, palette.count == 1024,
              opaque == nil || opaque?.count == pixels.count else {
            throw SequelDataError.invalid("Invalid indexed sequel artwork frame.")
        }
        var bytes = [UInt8](repeating: 0, count: pixels.count * 4)
        for i in pixels.indices where opaque?[i] ?? (palette[Int(pixels[i]) * 4 + 3] != 0) {
            let p = Int(pixels[i]) * 4
            bytes[i*4] = palette[p]; bytes[i*4+1] = palette[p+1]
            bytes[i*4+2] = palette[p+2]; bytes[i*4+3] = 255
        }
        try self.init(width: width, height: height, x: x, y: y, rgba: bytes, sourcePalette: palette)
    }
}

/// Exact discrete reconstruction. Each table entry was measured from DOS/Mac
/// pairs. Uncertain neighbourhoods retain their source block. There is no
/// interpolation or animation seed. Static texture uses an authored pixel phase.
public enum SequelMacArtwork {
    public static let revision = 6
    private static let offsets = [(0,0),(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]

    public struct PixelEdit: Sendable {
        public let x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8
        public init(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8) {
            self.x = x; self.y = y; self.red = red; self.green = green; self.blue = blue
        }
    }

    /// Asset-specific corrections use high-resolution coordinates and cannot
    /// change opacity, frame size, registration or animation state.
    public static func reconstruct(_ source: SequelMacFrame, category: SequelMacCategory,
                                   edits: [PixelEdit] = []) throws -> SequelMacFrame {
        let w = source.width, h = source.height
        guard w <= 4096, h <= 4096, w * h <= 4 * 1024 * 1024 else {
            throw SequelDataError.invalid("Sequel reconstruction exceeds the image limit.")
        }
        let ruleCategory: SequelMacCategory = category == .lemmings2Walker ? .sprite : category
        let table = Lemmings2MacRuleTables.tables[ruleCategory] ?? [:]
        let boundaries = Lemmings2MacRuleTables.boundaries[ruleCategory] ?? [:]
        // Zero is transparent. Opaque black has a nonzero alpha byte.
        var colours = [UInt32](repeating: 0, count: w*h)
        var light = [Int](repeating: 0, count: w*h)
        for i in colours.indices where source.rgba[i*4+3] != 0 {
            let r = source.rgba[i*4], g = source.rgba[i*4+1], b = source.rgba[i*4+2]
            colours[i] = UInt32(r) << 24 | UInt32(g) << 16 | UInt32(b) << 8 | 255
            light[i] = Int(r)*3 + Int(g)*6 + Int(b)
        }
        var output = [UInt8](repeating: 0, count: w*h*16)
        var unique = [UInt32](repeating: 0, count: 10)
        for y in 0..<h { for x in 0..<w {
            let center = y*w+x
            guard colours[center] != 0 else { continue }
            unique[0] = 0; unique[1] = colours[center]
            var count = 2
            var key: UInt64 = 0
            let r = Int(source.rgba[center*4]), g = Int(source.rgba[center*4+1]), b = Int(source.rgba[center*4+2])
            let hue: UInt64
            if max(r,max(g,b))-min(r,min(g,b)) < 24 { hue = 0 }
            else if r >= g && r >= b { hue = g <= b ? 1 : 2 }
            else if g >= b { hue = r >= b ? 3 : 4 }
            else { hue = g >= r ? 5 : 6 }
            key |= hue << 46
            for (i, offset) in offsets.enumerated() {
                let px = x+offset.0, py = y+offset.1
                let inside = px >= 0 && py >= 0 && px < w && py < h
                let position = inside ? py*w+px : 0
                let colour = inside ? colours[position] : 0
                var slot = 0
                while slot < count && unique[slot] != colour { slot += 1 }
                if slot == count { unique[count] = colour; count += 1 }
                key |= UInt64(slot) << (i*4)
                if colour != 0 && light[position] > light[center] { key |= UInt64(1) << (36+i) }
            }
            if ruleCategory == .sprite {
                if r >= 200 && g >= 160 && b >= 160 && r > g+15 && abs(g-b) < 24 {
                    key |= UInt64(1) << 45
                }
            }
            var recipe: UInt16 = table[key] ?? 0x1111
            if table[key] == nil && count > 2 {
                var centerMask: UInt64 = 0, opaqueMask: UInt64 = 0
                for i in 0..<9 {
                    let cell = (key >> (i*4)) & 15
                    if cell == 1 { centerMask |= 1 << i }
                    if cell != 0 { opaqueMask |= 1 << i }
                }
                var confidence: UInt16 = 0
                for candidate in 2..<count {
                    var mask: UInt64 = 0, brighter: UInt64 = 0
                    for i in 0..<9 where (key >> (i*4)) & 15 == UInt64(candidate) {
                        mask |= 1 << i; brighter = (key >> (36+i)) & 1
                    }
                    let signature = centerMask | (mask << 9) | (opaqueMask << 18) | (brighter << 27) | (hue << 28)
                    if let rule = boundaries[signature], rule >> 4 > confidence {
                        confidence = rule >> 4; recipe = 0
                        for i in 0..<4 { recipe |= UInt16(rule & (1 << i) != 0 ? candidate : 1) << (i*4) }
                    }
                }
            }
            for dy in 0..<2 { for dx in 0..<2 {
                let slot = Int((recipe >> ((dy*2+dx)*4)) & 15)
                // A malformed generated rule must never erase an opaque pixel.
                let colour: UInt32
                if ruleCategory == .sprite && key & (UInt64(1) << 45) != 0 && slot == 10 {
                    colour = 0xffaa22ff // Authored Macintosh face colour.
                } else if ruleCategory == .sprite && key & (UInt64(1) << 45) != 0 && slot == 11 {
                    colour = 0x660011ff // Authored Macintosh eye colour.
                } else { colour = slot > 0 && slot < count ? unique[slot] : colours[center] }
                let p = ((y*2+dy)*w*2+x*2+dx)*4
                output[p] = UInt8(truncatingIfNeeded: colour >> 24)
                output[p+1] = UInt8(truncatingIfNeeded: colour >> 16)
                output[p+2] = UInt8(truncatingIfNeeded: colour >> 8); output[p+3] = 255
            } }
        } }
        if category == .organic { organicTexture(source, colours: colours, light: light, output: &output) }
        if ruleCategory == .sprite {
            characterDetails(source, indexedWalker: category == .lemmings2Walker, output: &output)
        }
        if category == .mechanical { metalDetails(source, colours: colours, light: light, output: &output) }
        if category == .liquid {
            liquidBody(source, output: &output)
            liquidDetails(source, output: &output)
        }
        for edit in edits {
            guard edit.x >= 0, edit.y >= 0, edit.x < w*2, edit.y < h*2 else {
                throw SequelDataError.invalid("Artwork correction is outside its frame.")
            }
            let p = (edit.y*w*2+edit.x)*4
            guard output[p+3] == 255 else {
                throw SequelDataError.invalid("Artwork correction would change transparency.")
            }
            output[p] = edit.red; output[p+1] = edit.green; output[p+2] = edit.blue
        }
        return try SequelMacFrame(width: w*2, height: h*2, x: source.x*2, y: source.y*2, rgba: output,
                                 sourcePalette: source.sourcePalette)
    }

    private static func colourHue(_ colour: UInt32) -> UInt64 {
        let r = Int(colour >> 24), g = Int((colour >> 16) & 255), b = Int((colour >> 8) & 255)
        if max(r,max(g,b))-min(r,min(g,b)) < 24 { return 0 }
        if r >= g && r >= b { return g <= b ? 1 : 2 }
        if g >= b { return r >= b ? 3 : 4 }
        return g >= r ? 5 : 6
    }

    /// Mac dirt subdivides existing mottled regions into small palette clusters.
    /// The measured table selects a 2x2 mark from source gradient directions.
    /// Flat fills and silhouettes are excluded. The fallback phase stays fixed
    /// in terrain coordinates; there is no random seed or animation clock.
    private static func organicTexture(_ source: SequelMacFrame, colours: [UInt32], light: [Int], output: inout [UInt8]) {
        let w = source.width, h = source.height
        guard w >= 3, h >= 3 else { return }
        let palette: [UInt32]
        if let bytes = source.sourcePalette {
            palette = Set(stride(from: 0, to: bytes.count, by: 4).compactMap { i -> UInt32? in
                guard bytes[i+3] != 0 else { return nil }
                return UInt32(bytes[i]) << 24 | UInt32(bytes[i+1]) << 16 | UInt32(bytes[i+2]) << 8 | 255
            }).sorted()
        } else { palette = Set(colours).filter { $0 != 0 }.sorted() }
        func components(_ c: UInt32) -> (Int,Int,Int) {
            (Int(c >> 24),Int((c >> 16)&255),Int((c >> 8)&255))
        }
        var ramps: [UInt32:(UInt32,UInt32)] = [:]
        let background: UInt32? = source.sourcePalette.map { p in
            UInt32(p[0]) << 24 | UInt32(p[1]) << 16 | UInt32(p[2]) << 8 | 255
        }
        for colour in palette {
            let (r,g,b) = components(colour), lum = r*3+g*6+b
            var up = colour, down = colour, upDistance = Int.max, downDistance = Int.max
            for candidate in palette where candidate >> 8 != 0 && candidate != background {
                let (cr,cg,cb) = components(candidate), cl = cr*3+cg*6+cb
                let distance = (cr-r)*(cr-r)+(cg-g)*(cg-g)+(cb-b)*(cb-b)
                if cl > lum && distance < upDistance { up = candidate; upDistance = distance }
                if cl < lum && distance < downDistance { down = candidate; downDistance = distance }
            }
            ramps[colour] = (up,down)
        }
        let adjacent = [-w,-1,1,w]
        var local = [UInt32](repeating: 0, count: 9)
        for y in 1..<(h-1) { for x in 1..<(w-1) {
            let center = y*w+x, colour = colours[center]
            guard colour != 0 else { continue }
            var count = 0, transparent = false
            for dy in -1...1 { for dx in -1...1 {
                let c = colours[center+dy*w+dx]
                if c == 0 { transparent = true }
                var found = false
                for i in 0..<count where local[i] == c { found = true; break }
                if !found { local[count] = c; count += 1 }
            } }
            guard !transparent, count >= 2 else { continue }
            var key = UInt64(min(5,count)) << 8 | colourHue(colour) << 11
            for (i,offset) in adjacent.enumerated() {
                let value: UInt64 = light[center+offset] == light[center] ? 0 : light[center+offset] > light[center] ? 1 : 2
                key |= value << (i*2)
            }
            guard let ramp = ramps[colour] else { continue }
            let recipe = Lemmings2MacRuleTables.texture[key]
            let (r,g,b) = components(colour)
            let rough = max(r,max(g,b))-min(r,min(g,b)) >= 48 && r+g+b >= 80
            for i in 0..<4 {
                let brushX = ((source.x+x)*2+i%2) & 7
                let brushY = ((source.y+y)*2+i/2) & 7
                let token = recipe.map { ($0 >> (i*2)) & 3 }
                    ?? (rough ? UInt16(Lemmings2MacRuleTables.organicBrush[brushY*8+brushX]) : 0)
                guard token != 0 else { continue }
                let pixel = token == 1 ? ramp.0 : ramp.1
                let p = ((y*2+i/2)*w*2+x*2+i%2)*4
                output[p] = UInt8(truncatingIfNeeded:pixel >> 24)
                output[p+1] = UInt8(truncatingIfNeeded:pixel >> 16)
                output[p+2] = UInt8(truncatingIfNeeded:pixel >> 8)
            }
        } }
    }

    /// Fill the transparent tail below an existing liquid column.
    /// Liquid animation frames often store only the moving surface. The
    /// frame bounds still define the body area, so fill only below source
    /// pixels that already belong to the liquid. Empty columns stay clear.
    private static func liquidBody(_ source: SequelMacFrame, output: inout [UInt8]) {
        let w = source.width, h = source.height
        guard w > 0, h > 1 else { return }
        for x in 0..<w {
            var lastOpaque: Int?
            for y in 0..<h where source.rgba[(y * w + x) * 4 + 3] == 255 {
                lastOpaque = y
            }
            guard let lastOpaque, lastOpaque < h - 1 else { continue }
            let bodyPixel = ((lastOpaque * 2) * w * 2 + x * 2) * 4
            for y in (lastOpaque + 1)..<h {
                for dy in 0..<2 {
                    for dx in 0..<2 {
                        let pixel = ((y * 2 + dy) * w * 2 + x * 2 + dx) * 4
                        output[pixel] = output[bodyPixel]
                        output[pixel + 1] = output[bodyPixel + 1]
                        output[pixel + 2] = output[bodyPixel + 2]
                        output[pixel + 3] = 255
                    }
                }
            }
        }
    }

    /// Mac wave glints use one-pixel horizontal marks above a flat body.
    /// Thin an existing bright glint using its own liquid colour underneath it.
    /// Isolated glints become one pixel; connected crests keep a horizontal pair.
    private static func liquidDetails(_ source: SequelMacFrame, output: inout [UInt8]) {
        let w = source.width, h = source.height
        guard w >= 3, h >= 2 else { return }
        for y in 0..<(h-1) { for x in 1..<(w-1) {
            let i = (y*w+x)*4, below = i+w*4
            guard source.rgba[i+3] == 255 && source.rgba[below+3] == 255 else { continue }
            let high = Int(source.rgba[i])*3+Int(source.rgba[i+1])*6+Int(source.rgba[i+2])
            let belowLight = Int(source.rgba[below])*3+Int(source.rgba[below+1])*6+Int(source.rgba[below+2])
            let low = min(source.rgba[below],min(source.rgba[below+1],source.rgba[below+2]))
            let bright = max(source.rgba[below],max(source.rgba[below+1],source.rgba[below+2]))
            guard high >= 1280 && Int(bright)-Int(low) >= 60 && high-belowLight >= 160 else { continue }
            let neighbour = source.rgba[i-4..<i-1] == source.rgba[i..<i+3]
                || source.rgba[i+4..<i+7] == source.rgba[i..<i+3]
            for pixel in (neighbour ? 2 : 1)..<4 {
                let p = ((y*2+pixel/2)*w*2+x*2+pixel%2)*4
                for c in 0..<3 { output[p+c] = source.rgba[below+c] }
            }
        } }
    }

    /// Macintosh metal uses small faceted studs inside its dark joints.
    /// Round only compact neutral highlights, using their existing dark rim.
    /// Large flat panels, coloured surfaces and the opacity boundary are excluded.
    private static func metalDetails(_ source: SequelMacFrame, colours: [UInt32], light: [Int], output: inout [UInt8]) {
        let w = source.width, h = source.height
        guard w >= 3, h >= 3 else { return }
        func neutral(_ c: UInt32) -> Bool {
            let r = Int(c >> 24), g = Int((c >> 16)&255), b = Int((c >> 8)&255)
            return c != 0 && max(r,max(g,b))-min(r,min(g,b)) <= 32
        }
        var visited = [Bool](repeating: false, count: colours.count)
        for start in colours.indices where !visited[start] && light[start] >= 960 && neutral(colours[start]) {
            var component = [start], cursor = 0
            visited[start] = true
            while cursor < component.count {
                let p = component[cursor]; cursor += 1
                for (dx,dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                    let x = p%w+dx, y = p/w+dy
                    guard x >= 0, x < w, y >= 0, y < h else { continue }
                    let n = y*w+x
                    if !visited[n] && colours[n] == colours[start] { visited[n] = true; component.append(n) }
                }
            }
            guard component.count <= 9,
                  component.map({$0%w}).max()!-component.map({$0%w}).min()! < 3,
                  component.map({$0/w}).max()!-component.map({$0/w}).min()! < 3 else { continue }
            for p in component {
                let x = p%w, y = p/w
                guard x > 0, x < w-1, y > 0, y < h-1 else { continue }
                var marks: [(Int,Int)] = []
                for corner in 0..<4 {
                    let a = p+(corner%2 == 0 ? -1 : 1), b = p+(corner/2 == 0 ? -w : w)
                    guard neutral(colours[a]), neutral(colours[b]),
                          light[p]-light[a] >= 120, light[p]-light[b] >= 120 else { continue }
                    marks.append((corner,light[a] >= light[b] ? a : b))
                }
                // A one-pixel stud keeps its upper highlight rather than vanishing.
                if marks.count > 2 { marks = marks.filter {$0.0 >= 2} }
                for (corner,n) in marks {
                    let d = ((y*2+corner/2)*w*2+x*2+corner%2)*4
                    for c in 0..<3 { output[d+c] = source.rgba[n*4+c] }
                }
            }
        }
    }

    /// The Mac walker separates the face from pale sleeves and shoes, then
    /// places a single dark eye below the hair. This curated rule follows that
    /// arrangement. It reads actor-local colours, never the animation clock.
    private static func characterDetails(_ source: SequelMacFrame, indexedWalker: Bool, output: inout [UInt8]) {
        let w = source.width, h = source.height
        guard w <= 64, h <= 64 else { return }
        // WALKER.DAT defines clothing, hair and skin as indices 1, 2 and 3.
        // Tribe palettes include tan skin and red, blue or dark hair.
        let walkerPalette = indexedWalker ? source.sourcePalette : nil
        func matches(_ pixel: Int, colour: Int) -> Bool {
            guard let walkerPalette else { return false }
            return source.rgba[pixel*4..<pixel*4+3] == walkerPalette[colour*4..<colour*4+3]
        }
        var hair: [Int] = []
        for i in 0..<(w*h) where source.rgba[i*4+3] != 0 {
            let r = Int(source.rgba[i*4]), g = Int(source.rgba[i*4+1]), b = Int(source.rgba[i*4+2])
            if walkerPalette != nil ? matches(i, colour: 2) : g > 70 && g > r*3/2 && g > b*3/2 {
                hair.append(i)
            }
        }
        guard hair.count >= 2, hair.count <= 96 else { return }
        let left = hair.map { $0%w }.min()!, right = hair.map { $0%w }.max()!
        let top = hair.map { $0/w }.min()!, bottom = hair.map { $0/w }.max()!
        guard right-left <= 15, bottom-top <= 9 else { return }
        var face: [Int] = []
        for y in top...min(h-1,bottom+1) { for x in max(0,left-1)...min(w-1,right+2) {
            let i = y*w+x, r = Int(source.rgba[i*4]), g = Int(source.rgba[i*4+1]), b = Int(source.rgba[i*4+2])
            let skin = walkerPalette != nil ? matches(i, colour: 3)
                : r >= 140 && g >= 120 && b >= 120 && r >= g && max(r,max(g,b))-min(r,min(g,b)) < 80
            if source.rgba[i*4+3] != 0 && skin { face.append(i) }
        } }
        guard !face.isEmpty, face.count <= 24 else { return }
        if walkerPalette != nil {
            // Separate pale cuffs and shoes from the warm face in every tribe.
            for i in 0..<(w*h) where source.rgba[i*4+3] != 0 && matches(i, colour: 3) {
                for dy in 0..<2 { for dx in 0..<2 {
                    let p = (((i/w)*2+dy)*w*2+(i%w)*2+dx)*4
                    output[p] = 255; output[p+1] = 255; output[p+2] = 255
                } }
            }
        }
        let faceTop = face.map { $0/w }.min()!
        // Retain the pale forehead row. The broad cheek uses the authored gold.
        for i in face { for dy in 0..<2 { for dx in 0..<2 {
            guard i/w > faceTop || dy == 1 else { continue }
            let p = (((i/w)*2+dy)*w*2+(i%w)*2+dx)*4
            output[p] = 255; output[p+1] = 170; output[p+2] = 34
        } } }
        let firstRow = face.filter { $0/w == faceTop }
        let middle = firstRow.reduce(0) { $0+$1%w }*2/firstRow.count
        // A centred face has no reliable facing direction, so omit its eye.
        guard middle != left+right else { return }
        let rightFacing = middle > left+right
        let eye = rightFacing ? firstRow.max()! : firstRow.min()!
        let p = (((eye/w)*2+1)*w*2+(eye%w)*2+(rightFacing ? 1 : 0))*4
        output[p] = 102; output[p+1] = 0; output[p+2] = 17
    }
}
