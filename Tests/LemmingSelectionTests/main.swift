import Foundation
import CoreGraphics
import ImageIO
import Metal

@main struct LemmingSelectionChecks {
 @MainActor static func main() throws {
  let spriteContext = CGContext(data: nil, width: 8, height: 16, bitsPerComponent: 8, bytesPerRow: 32,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  spriteContext.setFillColor(CGColor(srgbRed: 0.2, green: 0.8, blue: 0.4, alpha: 1))
  spriteContext.fill(CGRect(x: 2, y: 0, width: 4, height: 13))
  let sprite = spriteContext.makeImage()!
  let board = CGContext(data: nil, width: 720, height: 220, bitsPerComponent: 8, bytesPerRow: 720 * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  board.translateBy(x: 0, y: 220); board.scaleBy(x: 1, y: -1)
  board.setFillColor(CGColor(gray: 0.12, alpha: 1)); board.fill(CGRect(x: 0, y: 0, width: 720, height: 220))
  for (index, scale) in [CGFloat(1), 2, 3.3].enumerated() {
   let rect = CGRect(x: 70 + CGFloat(index) * 210, y: 90, width: 8 * scale, height: 16 * scale)
   var effect = LemmingSelectionEffect(sprite: sprite, rect: rect, clipRect: CGRect(x: 0,y: 0,width: 720,height: 220))
   let marker = LemmingSelectionRenderer.plumbobRect(for: effect)
   precondition(marker.maxY < rect.minY)
   for opacity in [CGFloat(1), 0.5, 0] {
    effect.opacity = opacity
    let check = CGContext(data: nil,width: 720,height: 220,bitsPerComponent: 8,bytesPerRow: 720*4,
     space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    check.translateBy(x: 0, y: 220); check.scaleBy(x: 1, y: -1)
    LemmingSelectionRenderer.draw(effect, in: check)
    let data = check.data!.assumingMemoryBound(to: UInt8.self)
    let offset = (Int(marker.midY) * 720 + Int(marker.midX)) * 4
    precondition(abs(Int(data[offset+3]) - Int((255 * opacity).rounded())) <= 1)
    if opacity > 0 { precondition(data[offset+1] > data[offset]) }

   }
   effect.opacity = 1
   for rescue in [false, true] {
    effect.rescueAmount = rescue ? 1 : 0
    effect.clipRect = rescue ? CGRect(x: 0, y: 0, width: 720, height: 220) : rect
    let isolated = CGContext(data: nil, width: 720, height: 220, bitsPerComponent: 8, bytesPerRow: 720 * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    isolated.translateBy(x: 0, y: 220); isolated.scaleBy(x: 1, y: -1)
    LemmingSelectionRenderer.draw(effect, in: isolated)
    let data = isolated.data!.assumingMemoryBound(to: UInt8.self)
    let offset = (Int(marker.midY) * 720 + Int(marker.midX)) * 4
    precondition(data[offset + 3] < 40, "Rescue or clipped effect drew a diamond")
   }
   effect.rescueAmount = 0
   effect.clipRect = CGRect(x: 0, y: 0, width: 720, height: 220)
   board.saveGState(); board.translateBy(x: rect.minX,y: rect.maxY); board.scaleBy(x: 1,y: -1)
   board.draw(sprite, in: CGRect(origin: .zero,size: rect.size)); board.restoreGState()
   LemmingSelectionRenderer.draw(effect, in: board)
   LemmingSelectionRenderer.drawObvious(at: CGPoint(x: rect.midX + 80,y: rect.minY + 10 * scale),scale: scale,animated: false,context: board)
  }
  let file = URL(fileURLWithPath: CommandLine.arguments[1])
  let dest = CGImageDestinationCreateWithURL(file as CFURL,"public.png" as CFString,1,nil)!
  CGImageDestinationAddImage(dest,board.makeImage()!,nil); precondition(CGImageDestinationFinalize(dest))
  if let gpu = MTLCreateSystemDefaultDevice() {
   _ = try gpu.makeLibrary(source: LemmingSelectionRenderer.shader, options: nil)
   print("PASS Metal selection shader compilation")
  } else { print("Metal device unavailable headlessly") }
  print("PASS pixel diamond at 1x, 2x, fractional zoom; full, half and zero opacity; clipping; rescue exclusion; no windows or audio")
 }
}
