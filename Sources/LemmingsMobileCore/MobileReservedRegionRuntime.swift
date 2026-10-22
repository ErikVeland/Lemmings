#if canImport(ObjectiveC)
import Foundation
import ObjectiveC

/**
 * Reads public Duo selectors on newer systems without linking against a newer SDK.
 * Apple documents these selectors under UIViewReservedRegion and UIViewReservedRegionKind.
 */
@MainActor public enum MobileReservedRegionRuntime {
    public struct Region {
        public let frame: MobileRect
        public let active: Bool
    }

    /**
     * Returns a public region kind only when its class and factory exist at runtime.
     */
    public static func kind(_ name: String, resolveClass: (String) -> AnyClass? = NSClassFromString) -> NSObject? {
        guard let type = resolveClass("UIViewReservedRegionKind") else { return nil }
        let selector = NSSelectorFromString(name)
        guard let method = class_getClassMethod(type, selector), method_getNumberOfArguments(method) == 2,
              returnType(method) == "@" else { return nil }
        typealias Factory = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let call = unsafeBitCast(method_getImplementation(method), to: Factory.self)
        return call(type as AnyObject, selector)?.takeUnretainedValue() as? NSObject
    }

    /**
     * Decodes only the documented object, CGRect and BOOL signatures. Older systems return no regions.
     */
    public static func regions(in view: NSObject, kind: NSObject, includeInactive: Bool = false) -> [Region] {
        let values = query(view, kind: kind, includeInactive: includeInactive)
        return values.compactMap { value in
            let frameSelector = NSSelectorFromString("frame")
            let activeSelector = NSSelectorFromString("isActive")
            guard let frameMethod = class_getInstanceMethod(type(of: value), frameSelector),
                  let activeMethod = class_getInstanceMethod(type(of: value), activeSelector),
                  method_getNumberOfArguments(frameMethod) == 2, method_getNumberOfArguments(activeMethod) == 2,
                  returnType(frameMethod).hasPrefix("{CGRect="), ["B", "c"].contains(returnType(activeMethod)) else { return nil }
            typealias FrameGetter = @convention(c) (AnyObject, Selector) -> CGRect
            typealias ActiveGetter = @convention(c) (AnyObject, Selector) -> Bool
            let getFrame = unsafeBitCast(method_getImplementation(frameMethod), to: FrameGetter.self)
            let getActive = unsafeBitCast(method_getImplementation(activeMethod), to: ActiveGetter.self)
            let frame = getFrame(value, frameSelector)
            let active = getActive(value, activeSelector)
            guard (includeInactive || active), frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0 else { return nil }
            return Region(frame: .init(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height), active: active)
        }
    }

    /**
     * An inactive fold can have an empty frame. Its presence still identifies the device capability.
     */
    public static func hasRegions(in view: NSObject, kind: NSObject, includeInactive: Bool) -> Bool {
        !query(view, kind: kind, includeInactive: includeInactive).isEmpty
    }

    private static func query(_ view: NSObject, kind: NSObject, includeInactive: Bool) -> [NSObject] {
        let selector = NSSelectorFromString("reservedRegionsOfKind:options:")
        guard let method = class_getInstanceMethod(type(of: view), selector), method_getNumberOfArguments(method) == 4,
              returnType(method) == "@", argumentType(method, 2) == "@", argumentType(method, 3) == "Q" else { return [] }
        typealias Query = @convention(c) (AnyObject, Selector, AnyObject, UInt) -> Unmanaged<AnyObject>?
        let call = unsafeBitCast(method_getImplementation(method), to: Query.self)
        // UIViewReservedRegionQueryOptionsIncludeInactive is the first NSUInteger option bit.
        let options: UInt = includeInactive ? 1 << 0 : 0
        return call(view, selector, kind, options)?.takeUnretainedValue() as? [NSObject] ?? []
    }

    public static func integer(_ name: String, in object: NSObject) -> Int? {
        let selector = NSSelectorFromString(name)
        guard let method = class_getInstanceMethod(type(of: object), selector), method_getNumberOfArguments(method) == 2,
              ["q", "Q"].contains(returnType(method)) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> Int
        return unsafeBitCast(method_getImplementation(method), to: Getter.self)(object, selector)
    }

    private static func returnType(_ method: Method) -> String {
        let value = method_copyReturnType(method)
        defer { free(value) }
        return String(cString: value)
    }

    private static func argumentType(_ method: Method, _ index: UInt32) -> String {
        guard let value = method_copyArgumentType(method, index) else { return "" }
        defer { free(value) }
        return String(cString: value)
    }
}
#endif
