import Foundation

/// Shape reinforces assignment availability without changing the target area.
public enum AssignmentPointerShape {
    public static func marks(in frame: CGRect, arm: CGFloat, stroke: CGFloat,
                             occupied: Bool, eligible: Bool) -> [CGRect] {
        let length = occupied || eligible ? arm : max(stroke * 2, floor(arm / 2))
        var marks: [CGRect] = []
        for left in [true, false] {
            for top in [true, false] {
                marks.append(CGRect(x: left ? frame.minX : frame.maxX - length,
                                    y: top ? frame.minY : frame.maxY - stroke,
                                    width: length, height: stroke))
                marks.append(CGRect(x: left ? frame.minX : frame.maxX - stroke,
                                    y: top ? frame.minY : frame.maxY - length,
                                    width: stroke, height: length))
            }
        }
        if occupied && !eligible {
            let x = floor(frame.midX / stroke) * stroke
            let y = floor(frame.midY / stroke) * stroke
            for step in -2...2 {
                let offset = CGFloat(step) * stroke
                marks.append(CGRect(x: x + offset, y: y + offset, width: stroke, height: stroke))
                if step != 0 {
                    marks.append(CGRect(x: x + offset, y: y - offset, width: stroke, height: stroke))
                }
            }
        }
        return marks
    }
}
