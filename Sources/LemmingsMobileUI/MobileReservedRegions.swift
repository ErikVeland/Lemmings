#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileSystemRegions {
    static func read(in view: UIView) -> [MobileReservedRegion] {
        #if os(iOS) && compiler(>=6.3)
        if #available(iOS 27.1, *) {
            return [UIView.ReservedRegion.Kind.division, .occlusion].flatMap { kind in
                view.reservedRegions(kind: kind).filter(\.isActive).map { region in
                    MobileReservedRegion(kind: kind == .division ? .division : .occlusion,
                                         frame: MobileRect(x: region.frame.minX, y: region.frame.minY,
                                                           width: region.frame.width, height: region.frame.height))
                }
            }
        }
        #endif
        return []
    }

    /// Extra horizontal clearance for the header, relative to the ordinary safe area.
    static func topBarInsets(in view: UIView) -> MobileInsets {
        #if os(iOS)
        let safe = view.safeAreaInsets
        guard #available(iOS 26.0, *) else { return .init() }
        let corners = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
        var left = corners.left, right = corners.right
        if #available(iOS 27.1, *) {
            let bar = view.edgeInsets(for: .bar(onEdge: UIRectEdge.top, extent: MobileHUDLayout.rowHeight))
            left = max(left, bar.left); right = max(right, bar.right)
        }
        return MobileInsets(left: max(0, left - safe.left), right: max(0, right - safe.right))
        #else
        return .init()
        #endif
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
