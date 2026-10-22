#if canImport(ObjectiveC)
import Foundation
import Testing
@testable import LemmingsMobileCore

@MainActor @Suite struct MobileReservedRegionRuntimeTests {
    private final class Kind: NSObject {
        @objc class func divisionRegionKind() -> NSObject { NSObject() }
    }
    private final class Region: NSObject {
        @objc var frame = CGRect(x: 0, y: 300, width: 600, height: 20)
        @objc(isActive) var active = true
    }
    private final class Provider: NSObject {
        var values: [NSObject] = []
        var options: UInt = 0
        var receivedKind: NSObject?
        @objc(reservedRegionsOfKind:options:) func query(_ kind: NSObject, options: UInt) -> NSArray {
            self.options = options
            receivedKind = kind
            return values as NSArray
        }
        @objc var verticalBarEdge: Int { 2 }
    }
    private final class InvalidRegion: NSObject {
        @objc var frame: String { "wrong ABI" }
        @objc(isActive) var active = true
    }

    @Test func olderSystemsAndMissingFactoriesReturnNoRegions() {
        #expect(MobileReservedRegionRuntime.kind("divisionRegionKind", resolveClass: { _ in nil }) == nil)
        #expect(MobileReservedRegionRuntime.kind("missingFactory", resolveClass: { _ in Kind.self }) == nil)
        #expect(MobileReservedRegionRuntime.kind("divisionRegionKind", resolveClass: { _ in Kind.self }) != nil)
        #expect(MobileReservedRegionRuntime.regions(in: NSObject(), kind: NSObject()).isEmpty)
        #expect(MobileReservedRegionRuntime.integer("verticalBarEdge", in: NSObject()) == nil)
    }

    @Test func runtimeQueryKeepsTheFrameAndFiltersInactiveRegions() {
        let view = Provider(), active = Region(), inactive = Region(), kind = NSObject()
        inactive.active = false
        view.values = [active, inactive]
        let visible = MobileReservedRegionRuntime.regions(in: view, kind: kind)
        #expect(visible.count == 1)
        #expect(visible.first?.frame == .init(x: 0, y: 300, width: 600, height: 20))
        #expect(view.options == 0)
        #expect(view.receivedKind === kind)
        #expect(MobileReservedRegionRuntime.regions(in: view, kind: kind, includeInactive: true).count == 2)
        #expect(view.options == 1)
        #expect(MobileReservedRegionRuntime.integer("verticalBarEdge", in: view) == 2)
    }

    @Test func inactiveEmptyFoldStillIdentifiesTheDevice() {
        let view = Provider(), inactive = Region(), kind = NSObject()
        inactive.active = false
        inactive.frame = .zero
        view.values = [inactive]
        #expect(MobileReservedRegionRuntime.hasRegions(in: view, kind: kind, includeInactive: true))
        #expect(MobileReservedRegionRuntime.regions(in: view, kind: kind, includeInactive: true).isEmpty)
    }

    @Test func invalidGeometryAndUnexpectedSignaturesAreRejected() {
        let view = Provider(), empty = Region(), invalid = Region()
        empty.frame.size.width = 0
        invalid.frame.origin.x = .infinity
        view.values = [empty, invalid, InvalidRegion()]
        #expect(MobileReservedRegionRuntime.regions(in: view, kind: NSObject()).isEmpty)
    }
}
#endif
