import Foundation

/// Native chain wave, link geometry and fan amplitude (PROCESS 914d–93a3).
public struct Lemmings2Chain: Sendable {
    public struct Link: Sendable {
        public fileprivate(set) var x = 0
        public fileprivate(set) var y = 0
        public fileprivate(set) var frame = 0
        public fileprivate(set) var velocityX = 0
        public fileprivate(set) var velocityY = 0
        fileprivate var angle = 0
        fileprivate var amplitude = 0
        fileprivate var frequency = 0
        fileprivate var fixedX = 0
        fileprivate var fixedY = 0
    }
    public let id: Int
    public let x: Int
    public let y: Int
    public let controls: [Lemmings2Runtime.Rect]
    public private(set) var links: [Link]
    public private(set) var amplitude = 4
    private var countdown = 8
    private var phase = 320
    public init(id:Int,x:Int,y:Int,count:Int,controls:[Lemmings2Runtime.Rect]) {
        self.id = id; self.x = x; self.y = y; self.controls = controls
        links = Array(repeating:Link(),count:max(1,min(9,count)))
    }
    public mutating func step(fanX:Int,fanY:Int,power:Int) {
        let dx = x-fanX, dy = y-38-fanY
        let distance = max(1,Int(Double(dx*dx+dy*dy).squareRoot()))
        let strength = power > 0 ? min(67,((abs(dx)*256/distance)*(power/(dx*dx+dy*dy+1))) >> 9) : 0
        let target = strength+4
        if amplitude != target {
            countdown -= 1
            if countdown == 0 {
                amplitude = max(4,min(67,amplitude+(amplitude < target ? 8 : -2)))
                countdown = 8
            }
        }
        let frequency = (amplitude-4)>>5
        phase = (phase-(16-links.count)-frequency*2)&65535
        var fixedX = 0, fixedY = 0
        for index in links.indices {
            var link = links[index]
            let wave = Self.wave[((phase >> 1)+index*8)&255]
            if abs(wave) <= 15 {
                link.amplitude = index == 0 ? amplitude : links[index-1].amplitude
                link.frequency = index == 0 ? frequency : links[index-1].frequency
            }
            let old = Self.vectors[link.angle]
            fixedX += old.0; fixedY += old.1
            let factor = (index << link.frequency)+link.amplitude
            link.angle = ((((wave*factor) >> 6)+4)&0x1fc)/4
            let next = Self.vectors[link.angle]
            fixedX += next.0; fixedY += next.1
            link.frame = link.angle/2
            link.velocityX = max(-8,min(8,(fixedX-link.fixedX)>>7))
            link.velocityY = max(-8,min(8,(fixedY-link.fixedY)>>7))
            link.fixedX = fixedX; link.fixedY = fixedY
            link.x = x+(fixedX>>7); link.y = y+(fixedY>>7)
            links[index] = link
        }
    }
    public func catchingLink(x:Int,y:Int) -> Int? {
        let radius = links.count*12
        guard x >= self.x-radius, x <= self.x+radius, y >= self.y+12, y <= self.y+12+radius else { return nil }
        let margin = (amplitude+4)>>4
        return links.firstIndex { x >= $0.x+5-margin && x <= $0.x+11+margin && y >= $0.y+10 && y <= $0.y+22 }
    }
    public func riderPosition(link:Int) -> (x:Int,y:Int,pose:Int)? {
        guard links.indices.contains(link) else { return nil }
        let item = links[link], pose = item.frame/2
        let offsets = [(1,7),(2,7),(3,7),(3,6),(4,6),(5,5),(6,4),(6,3),(6,2),(6,1),(6,0),(5,0),(5,-1),(4,-2),(3,-2),(2,-2),(1,-2),(0,-2),(0,-2),(-1,-2),(-2,-1),(-2,0),(-3,0),(-3,1),(-3,2),(-3,3),(-3,3),(-3,4),(-2,5),(-1,6),(-1,6),(0,7)]
        return (item.x+7+offsets[pose].0,item.y+12+offsets[pose].1,pose)
    }
    private static let wave = [0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51, 54, 57, 59, 62, 65, 67, 70, 73, 75, 78, 80, 82, 85, 87, 89, 91, 94, 96, 98, 100, 102, 103, 105, 107, 108, 110, 112, 113, 114, 116, 117, 118, 119, 120, 121, 122, 123, 123, 124, 125, 125, 126, 126, 126, 126, 126, 127, 126, 126, 126, 126, 126, 125, 125, 124, 123, 123, 122, 121, 120, 119, 118, 117, 116, 114, 113, 112, 110, 108, 107, 105, 103, 102, 100, 98, 96, 94, 91, 89, 87, 85, 82, 80, 78, 75, 73, 70, 67, 65, 62, 59, 57, 54, 51, 48, 45, 42, 39, 36, 33, 30, 27, 24, 21, 18, 15, 12, 9, 6, 3, 0, -4, -7, -10, -13, -16, -19, -22, -25, -28, -31, -34, -37, -40, -43, -46, -49, -52, -55, -58, -60, -63, -66, -68, -71, -74, -76, -79, -81, -83, -86, -88, -90, -92, -95, -97, -99, -101, -103, -104, -106, -108, -109, -111, -113, -114, -115, -117, -118, -119, -120, -121, -122, -123, -124, -124, -125, -126, -126, -127, -127, -127, -127, -127, -127, -127, -127, -127, -127, -127, -126, -126, -125, -124, -124, -123, -122, -121, -120, -119, -118, -117, -115, -114, -113, -111, -109, -108, -106, -104, -103, -101, -99, -97, -95, -92, -90, -88, -86, -83, -81, -79, -76, -74, -71, -68, -66, -63, -60, -58, -55, -52, -49, -46, -43, -40, -37, -34, -31, -28, -25, -22, -19, -16, -13, -10, -7, -4]
    private static let vectors = [
        (0,660),
        (26,653),
        (60,653),
        (93,646),
        (126,646),
        (160,640),
        (186,626),
        (220,620),
        (246,606),
        (280,593),
        (306,580),
        (333,560),
        (366,546),
        (386,526),
        (413,506),
        (440,513),
        (466,466),
        (486,440),
        (506,413),
        (526,386),
        (546,366),
        (560,333),
        (580,306),
        (593,280),
        (606,246),
        (620,220),
        (626,186),
        (640,160),
        (646,126),
        (646,93),
        (653,60),
        (653,26),
        (660,0),
        (653,-26),
        (653,-60),
        (646,-93),
        (646,-126),
        (640,-160),
        (626,-186),
        (620,-220),
        (606,-246),
        (593,-280),
        (580,-306),
        (560,-333),
        (546,-366),
        (526,-386),
        (506,-413),
        (513,-440),
        (466,-466),
        (440,-486),
        (413,-506),
        (386,-526),
        (366,-546),
        (333,-560),
        (306,-580),
        (280,-593),
        (246,-606),
        (220,-620),
        (186,-626),
        (160,-640),
        (126,-646),
        (93,-646),
        (60,-653),
        (26,-653),
        (0,-660),
        (-26,-653),
        (-60,-653),
        (-93,-646),
        (-126,-646),
        (-160,-640),
        (-186,-626),
        (-220,-620),
        (-246,-606),
        (-280,-593),
        (-306,-580),
        (-333,-560),
        (-366,-546),
        (-386,-526),
        (-413,-506),
        (-440,-513),
        (-466,-466),
        (-486,-440),
        (-506,-413),
        (-526,-386),
        (-546,-366),
        (-560,-333),
        (-580,-306),
        (-593,-280),
        (-606,-246),
        (-620,-220),
        (-626,-186),
        (-640,-160),
        (-646,-126),
        (-646,-93),
        (-653,-60),
        (-653,-26),
        (-660,0),
        (-653,26),
        (-653,60),
        (-646,93),
        (-646,126),
        (-640,160),
        (-626,186),
        (-620,220),
        (-606,246),
        (-593,280),
        (-580,306),
        (-560,333),
        (-546,366),
        (-526,386),
        (-506,413),
        (-513,440),
        (-466,466),
        (-440,486),
        (-413,506),
        (-386,526),
        (-366,546),
        (-333,560),
        (-306,580),
        (-280,593),
        (-246,606),
        (-220,620),
        (-186,626),
        (-160,640),
        (-126,646),
        (-93,646),
        (-60,653),
        (-26,653)
    ]
}
