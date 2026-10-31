#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import LemmingsGameArt
import UIKit

@MainActor enum MobileSystemRegions {
    private static let hingedWindows = NSHashTable<UIWindow>.weakObjects()

    private static var deviceHingeKey: String? {
        UIDevice.current.identifierForVendor.map { "mobile.hingeDevice." + $0.uuidString }
    }

    /// Hinge availability identifies the outer display too, where no division region need be supplied.
    static func noteHinge(in view: UIView) {
        guard let window = (view as? UIWindow) ?? view.window, !hingedWindows.contains(window) else { return }
        hingedWindows.add(window)
        if let key = deviceHingeKey { UserDefaults.standard.set(true, forKey: key) }
        window.rootViewController?.view.setNeedsLayout()
    }

    static func controlShape(in view: UIView) -> GameControlShape {
        #if os(iOS)
        isFoldable(in: view) ? .rounded : .square
        #else
        .square
        #endif
    }

    static func usesFullDisplay(in view: UIView) -> Bool {
        #if os(iOS)
        return isFoldable(in: view) && !read(in: view).contains { $0.kind == .division }
        #else
        return false
        #endif
    }

    /// The display is the canvas. Local occlusions constrain content, rather than reserving a whole edge.
    static func contentInsets(in view: UIView) -> UIEdgeInsets {
        guard isFoldable(in: view) else { return view.safeAreaInsets }
        // Keep the fixed rows full width; vertical clearance protects their content.
        if #available(iOS 26.0, tvOS 26.0, *) {
            let corners = view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
            return UIEdgeInsets(top: corners.top, left: 0, bottom: corners.bottom, right: 0)
        }
        return UIEdgeInsets(top: view.safeAreaInsets.top, left: 0,
                            bottom: view.safeAreaInsets.bottom, right: 0)
    }

    /**
     * Keeps controls clear of a foldable's vertical bar outside the safe area.
     */
    static func navigationRail(in view: UIView) -> MobileRect? {
        #if os(iOS)
        guard isFoldable(in: view), !usesFullDisplay(in: view) else { return nil }
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
        if let window = (view as? UIWindow) ?? view.window, hingedWindows.contains(window) { return true }
        if let key = deviceHingeKey, UserDefaults.standard.bool(forKey: key) { return true }
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
        if isFoldable(in: view) {
            let bounds = view.bounds
            let header = MobileRect(x: bounds.minX, y: bounds.minY + contentInsets(in: view).top,
                                    width: bounds.width, height: MobileHUDLayout.rowHeight)
            let free = clearFoldableRow(header, in: view)
            return MobileInsets(left: free.minX - bounds.minX, right: bounds.maxX - free.maxX)
        }
        let safe = view.safeAreaInsets
        guard #available(iOS 26.0, *) else { return .init() }
        let corners = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
        return MobileInsets(left: max(0, corners.left - safe.left), right: max(0, corners.right - safe.right))
        #else
        return .init()
        #endif
    }

    static func menuFrame(in view: UIView) -> CGRect {
        let regions = read(in: view)
        let fullDisplay = isFoldable(in: view) && !regions.contains { $0.kind == .division }
        if fullDisplay {
            let bounds = view.bounds
            let clear = MobileDisplayRegions.scrollingMenuFrame(
                in: MobileRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height),
                avoiding: regions)
            return CGRect(x: clear.x, y: clear.y, width: clear.width, height: clear.height)
        }
        let available: CGRect
        if isFoldable(in: view) {
            let corners = horizontalCornerClearance(in: view)
            available = view.bounds.inset(by: contentInsets(in: view))
                .inset(by: UIEdgeInsets(top: 0, left: corners.left, bottom: 0, right: corners.right))
        } else {
            available = view.safeAreaLayoutGuide.layoutFrame
        }
        let rect = menuFrame(
            in: MobileRect(x: available.minX, y: available.minY, width: available.width, height: available.height),
            avoiding: regions)
        #if DEBUG && os(iOS)
        recordMenuGeometry(in: view, regions: regions, frame: rect, fullDisplay: fullDisplay)
        #endif
        return CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    static func navigationFrame(in view: UIView, height: CGFloat, bottom: Bool) -> CGRect? {
        guard usesFullDisplay(in: view), height > 0 else { return nil }
        let bounds = view.bounds
        let row = MobileRect(x: bounds.minX, y: bottom ? bounds.maxY - height : bounds.minY,
                             width: bounds.width, height: height)
        let clear = clearFoldableRow(row, in: view)
        guard clear.width >= 280 else { return nil }
        return CGRect(x: clear.x, y: clear.y, width: clear.width, height: clear.height)
    }

    static func clearRow(_ frame: CGRect, in view: UIView) -> CGRect {
        guard isFoldable(in: view) else { return frame }
        let clear = clearFoldableRow(
            MobileRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height), in: view)
        return clear.width >= 44 ? CGRect(x: clear.x, y: clear.y, width: clear.width, height: clear.height) : frame
    }

    /// Screen-corner bounds let adaptive menus place actions before they reach the physical mask.
    static func cornerObstructions(in view: UIView) -> [MobileReservedRegion] {
        guard isFoldable(in: view) else { return [] }
        let bounds = view.bounds
        var radii = GameControlCornerRadii(topLeft: 20, topRight: 20, bottomLeft: 20, bottomRight: 20)
        if #available(iOS 26.0, tvOS 26.0, *) {
            radii = GameControlCornerRadii(topLeft: view.effectiveRadius(corner: .topLeft),
                topRight: view.effectiveRadius(corner: .topRight),
                bottomLeft: view.effectiveRadius(corner: .bottomLeft),
                bottomRight: view.effectiveRadius(corner: .bottomRight))
        }
        func obstruction(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> MobileReservedRegion? {
            let frame = CGRect(x: x, y: y, width: min(width, bounds.width / 2), height: min(height, bounds.height / 2))
                .intersection(bounds)
            guard !frame.isNull, !frame.isEmpty else { return nil }
            return MobileReservedRegion(kind: .occlusion,
                frame: MobileRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height))
        }
        return [
            obstruction(bounds.minX, bounds.minY, radii.topLeft, radii.topLeft),
            obstruction(bounds.maxX - radii.topRight, bounds.minY, radii.topRight, radii.topRight),
            obstruction(bounds.minX, bounds.maxY - radii.bottomLeft, radii.bottomLeft, radii.bottomLeft),
            obstruction(bounds.maxX - radii.bottomRight, bounds.maxY - radii.bottomRight, radii.bottomRight, radii.bottomRight),
        ].compactMap { $0 }
    }

    static func layoutObstructions(in view: UIView) -> [MobileReservedRegion] {
        read(in: view) + cornerObstructions(in: view)
    }

    /// Fixed Duo rows share the opened display's physical corner zone and local obstructions.
    private static func clearFoldableRow(_ frame: MobileRect, in view: UIView) -> MobileRect {
        let bounds = view.bounds
        let corners = horizontalCornerClearance(in: view)
        let leftCorner = corners.left
        let rightCorner = corners.right
        let minX = max(frame.minX, bounds.minX + leftCorner)
        let maxX = min(frame.maxX, bounds.maxX - rightCorner)
        let cornerSafe = MobileRect(x: minX, y: frame.minY, width: max(0, maxX - minX), height: frame.height)
        return MobileDisplayRegions.clearHorizontalFrame(cornerSafe, avoiding: read(in: view))
    }

    private static func horizontalCornerClearance(in view: UIView) -> UIEdgeInsets {
        var left: CGFloat = 20
        var right: CGFloat = 20
        if #available(iOS 26.0, tvOS 26.0, *) {
            let corners = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
            left = max(left, corners.left)
            right = max(right, corners.right)
        }
        return UIEdgeInsets(top: 0, left: left, bottom: 0, right: right)
    }

    /// Keep Main menu on the outer right in book view and above a tabletop hinge.
    static func menuFrame(in available: MobileRect, avoiding regions: [MobileReservedRegion]) -> MobileRect {
        if let right = MobileDisplayRegions.bookPanes(in: available, avoiding: regions).last { return right }
        if let upper = MobileDisplayRegions.tablePanes(in: available, avoiding: regions).first { return upper }
        return MobileDisplayRegions.scrollingMenuFrame(in: available, avoiding: regions)
    }

    #if DEBUG && os(iOS)
    /// Keep the latest scene geometry available when comparing a device report with UIKit's regions.
    private static func recordMenuGeometry(in view: UIView, regions: [MobileReservedRegion], frame: MobileRect, fullDisplay: Bool) {
        let snapshot = "bounds=\(view.bounds) safe=\(view.safeAreaInsets) fullDisplay=\(fullDisplay) regions=\(regions) menu=\(frame)"
        guard UserDefaults.standard.string(forKey: "DuoMenuDebugGeometry") != snapshot else { return }
        UserDefaults.standard.set(snapshot, forKey: "DuoMenuDebugGeometry")
        UserDefaults.standard.set(ProcessInfo.processInfo.operatingSystemVersionString, forKey: "DuoMenuDebugOS")
        UserDefaults.standard.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion"), forKey: "DuoMenuDebugBuild")
        var history = UserDefaults.standard.stringArray(forKey: "DuoMenuDebugHistory") ?? []
        history.append("\(ProcessInfo.processInfo.systemUptime) \(snapshot)")
        UserDefaults.standard.set(Array(history.suffix(24)), forKey: "DuoMenuDebugHistory")
        print("[DuoMenu] \(snapshot)")
    }
    #endif
}
#endif
