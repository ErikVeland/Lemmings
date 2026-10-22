#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileSystemRegions {
    /**
     * Keeps controls clear of a foldable's vertical bar outside the safe area.
     */
    static func navigationRail(in view: UIView) -> MobileRect? {
        #if os(iOS)
        guard isFoldable(in: view) else { return nil }
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let left = safe.minX - view.bounds.minX
        let right = view.bounds.maxX - safe.maxX
        guard max(left, right) >= 52, abs(left - right) >= 20 else { return nil }
        let onRight = right > left
        let width = onRight ? right : left
        let top = view.safeAreaInsets.top + 4
        let bottom = view.safeAreaInsets.bottom + 4
        return MobileRect(x: onRight ? safe.maxX + 4 : view.bounds.minX + 4,
            y: view.bounds.minY + top, width: width - 8,
            height: max(0, view.bounds.height - top - bottom))
        #else
        return nil
        #endif
    }

    /**
     * Detects inactive division regions through runtime selectors.
     */
    static func isFoldable(in view: UIView) -> Bool {
        guard let kind = MobileReservedRegionRuntime.kind("divisionRegionKind") else { return false }
        return MobileReservedRegionRuntime.hasRegions(in: view, kind: kind, includeInactive: true)
    }

    static func read(in view: UIView) -> [MobileReservedRegion] {
        [("divisionRegionKind", MobileReservedRegion.Kind.division), ("occlusionRegionKind", .occlusion)].flatMap { name, kind in
            guard let runtimeKind = MobileReservedRegionRuntime.kind(name) else { return [MobileReservedRegion]() }
            return MobileReservedRegionRuntime.regions(in: view, kind: runtimeKind).map { .init(kind: kind, frame: $0.frame) }
        }
    }

    /// Extra horizontal clearance for the header, relative to the ordinary safe area.
    static func topBarInsets(in view: UIView) -> MobileInsets {
        #if os(iOS)
        let safe = view.safeAreaInsets
        guard #available(iOS 26.0, *) else { return .init() }
        let corners = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
        return MobileInsets(left: max(0, corners.left - safe.left), right: max(0, corners.right - safe.right))
        #else
        return .init()
        #endif
    }

    static func menuFrame(in view: UIView) -> CGRect {
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let rect = MobileDisplayRegions.menuFrame(
            in: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height), avoiding: read(in: view))
        return CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
