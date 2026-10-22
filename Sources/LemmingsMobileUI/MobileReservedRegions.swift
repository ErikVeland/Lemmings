#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileSystemRegions {
    /// The vertical bar is outside the content safe area. Keep its controls clear of curved corners.
    static func navigationRail(in view: UIView) -> MobileRect? {
        #if os(iOS) && compiler(>=6.3)
        if #available(iOS 27.1, *), view.traitCollection.verticalBarEdge != .unspecified {
            let safe = view.safeAreaLayoutGuide.layoutFrame
            let trailing = view.traitCollection.verticalBarEdge == .trailing
            let right = trailing == (view.effectiveUserInterfaceLayoutDirection == .leftToRight)
            let width = right ? view.bounds.maxX - safe.maxX : safe.minX - view.bounds.minX
            guard width >= 52 else { return nil }
            let edge: UIRectEdge = right ? .right : .left
            let bar = view.edgeInsets(for: .bar(onEdge: edge, extent: width))
            let top = max(view.safeAreaInsets.top, bar.top) + 4
            let bottom = max(view.safeAreaInsets.bottom, bar.bottom) + 4
            return MobileRect(x: right ? safe.maxX + 4 : view.bounds.minX + 4,
                y: view.bounds.minY + top, width: width - 8,
                height: max(0, view.bounds.height - top - bottom))
        }
        #endif
        return nil
    }

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

    /// A foldable reports its division even while closed, when the region is inactive.
    static func isFoldable(in view: UIView) -> Bool {
        #if os(iOS) && compiler(>=6.3)
        if #available(iOS 27.1, *) {
            return !view.reservedRegions(kind: .division, options: .includeInactive).isEmpty
        }
        #endif
        return false
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
