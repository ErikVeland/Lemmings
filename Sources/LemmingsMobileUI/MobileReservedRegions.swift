#if os(iOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileSystemRegions {
    static func read(in view: UIView) -> [MobileReservedRegion] {
        if #available(iOS 27.1, *) {
            return [UIView.ReservedRegion.Kind.division, .occlusion].flatMap { kind in
                view.reservedRegions(kind: kind).filter(\.isActive).map { region in
                    MobileReservedRegion(kind: kind == .division ? .division : .occlusion,
                                         frame: MobileRect(x: region.frame.minX, y: region.frame.minY,
                                                           width: region.frame.width, height: region.frame.height))
                }
            }
        }
        return []
    }

    static func menuFrame(in view: UIView) -> CGRect {
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let rect = MobileDisplayRegions.menuFrame(
            in: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
            avoiding: read(in: view))
        return CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
