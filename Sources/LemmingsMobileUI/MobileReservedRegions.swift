#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileSystemRegions {
    /**
     * Public runtime selectors preserve Duo support when building with the Tahoe-compatible SDK.
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

    /**
     * The live safe area identifies the physical side of a public vertical-bar trait, including RTL layouts.
     */
    static func navigationRail(in view: UIView) -> MobileRect? {
        guard let edge = MobileReservedRegionRuntime.integer("verticalBarEdge", in: view.traitCollection), edge != 0 else { return nil }
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let left = safe.minX - view.bounds.minX, right = view.bounds.maxX - safe.maxX
        let onRight = right > left
        let width = max(left, right)
        guard width >= 52 else { return nil }
        return MobileRect(x: onRight ? safe.maxX + 4 : view.bounds.minX + 4,
            y: view.bounds.minY + view.safeAreaInsets.top + 4, width: width - 8,
            height: max(0, view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom - 8))
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
