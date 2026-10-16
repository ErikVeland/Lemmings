import Foundation
import Metal
import NxlvKit
import XCTest

final class SourcePerformanceTests: XCTestCase {
    private var source: URL!
    private var assets: URL!
    private var cases: [BaselineCase] = []
    private var sink = 0
    private var metrics: [XCTMetric] { [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()] }
    private var options: XCTMeasureOptions {
        let value = XCTMeasureOptions(); value.iterationCount = 10; return value
    }

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        source = URL(fileURLWithPath: try XCTUnwrap(environment["BASELINE_SOURCE"]))
        assets = URL(fileURLWithPath: try XCTUnwrap(environment["BASELINE_ASSETS"]))
        cases = try JSONDecoder().decode([BaselineCase].self,
            from: Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(environment["BASELINE_CASES"]))))
    }

    func testDecodeClassicArchive() throws {
        let bytes = try Data(contentsOf: assets.appendingPathComponent("resources/Ports/lemmings_dos_1991-07-30/LEVEL000.DAT"))
        measure(metrics: metrics, options: options) {
            for _ in 0..<100 { self.sink &+= (try! ClassicDATArchive.decode(bytes)).count }
        }
    }

    func testDecodeNeoLevel() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "neo-typical" })
        let text = try String(contentsOf: assets.appendingPathComponent("neo/levels/" + item.level), encoding: .utf8)
        measure(metrics: metrics, options: options) {
            for _ in 0..<100 { self.sink &+= NxlvLevel(text: text)?.terrain.count ?? 0 }
        }
    }

    func testDecodeL2Level() throws {
        let bytes = try Data(contentsOf: assets.appendingPathComponent("resources/Ports/Lemm2/LEVELS/LEVEL000.DAT"))
        measure(metrics: metrics, options: options) {
            for _ in 0..<100 { self.sink &+= (try! Lemmings2Level(data: bytes)).tiles.count }
        }
    }

    func testDecodeL3Level() throws {
        let bytes = try Data(contentsOf: assets.appendingPathComponent("resources/Ports/LEM3CD/LEVELS/LEVEL001.DAT"))
        measure(metrics: metrics, options: options) {
            for _ in 0..<100 { self.sink &+= (try! Lemmings3Level(data: bytes)).width }
        }
    }

    func testLoadClassicFanLevel() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "classic-typical" })
        measure(metrics: metrics, options: options) {
            self.sink &+= (try! ClassicInput(item, assets: self.assets)).rendered.width
        }
    }

    func testLoadNeoLevel() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "neo-typical" })
        measure(metrics: metrics, options: options) {
            self.sink &+= (try! NeoInput(item, assets: self.assets)).rendered.width
        }
    }

    func testLoadL2Level() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "l2-typical" })
        measure(metrics: metrics, options: options) {
            self.sink &+= (try! L2Input(item, source: self.source, assets: self.assets)).base.configuration.width
        }
    }

    func testLoadL3Level() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "l3-typical" })
        measure(metrics: metrics, options: options) {
            self.sink &+= (try! L3Input(item, source: self.source, assets: self.assets)).base.configuration.width
        }
    }

    func testClassicRenderToTexture() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "classic-typical" })
        let input = try ClassicInput(item, assets: assets)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Headless Metal device unavailable")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
            width: input.rendered.width, height: input.rendered.height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        let rowBytes = texture.width * 4
        measure(metrics: metrics, options: options) {
            let pixels = ClassicSceneFrame.rgba(input.rendered, simulation: input.base)
            pixels.withUnsafeBytes { bytes in
                texture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: rowBytes)
            }
            self.sink &+= pixels.count
        }
        var readback = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&readback, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        XCTAssertEqual(Data(readback), ClassicSceneFrame.rgba(input.rendered, simulation: input.base))
    }

    func testClassicRewindCaptureTick() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "classic-typical" })
        let input = try ClassicInput(item, assets: assets)
        var prepared = ClassicDOSRewind(simulation: input.base)
        for _ in 0..<50 { prepared.tick() }
        XCTAssertEqual(prepared.keyframeCount, 1)
        measure(metrics: metrics, options: options) {
            var history = prepared
            history.tick()
            self.sink &+= history.keyframeCount
        }
        var captured = prepared; captured.tick()
        XCTAssertEqual(captured.keyframeCount, 2)
        var direct = prepared.simulation; direct.tick()
        XCTAssertEqual(captured.simulation, direct)
    }

    func testClassicRewindCheckpointEncoding() throws {
        let item = try XCTUnwrap(cases.first { $0.id == "classic-typical" })
        var history = ClassicDOSRewind(simulation: try ClassicInput(item, assets: assets).base)
        for _ in 0..<153 { history.tick() }
        measure(metrics: metrics, options: options) {
            self.sink &+= (try! JSONEncoder().encode(history)).count
        }
        let restored = try JSONDecoder().decode(ClassicDOSRewind.self, from: JSONEncoder().encode(history))
        XCTAssertEqual(restored.simulation, history.simulation)
    }
}
