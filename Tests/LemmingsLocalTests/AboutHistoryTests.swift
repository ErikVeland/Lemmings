#if os(macOS)
import AppKit
import XCTest
@testable import LemmingsLocal

final class AboutHistoryTests: XCTestCase {
    @MainActor func testHeritageCreditsKeepTheirBitmapReadingColumnAndScroll() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let markdown = try String(contentsOf: root.appendingPathComponent("Resources/About/Heritage.md"), encoding: .utf8)
        let credits = AboutMarkdownView(markdown: markdown)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 992, height: 460),
            styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = credits
        let output = root.appendingPathComponent(".build/heritage-about-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [772, 992, 1472] {
            window.setContentSize(CGSize(width: width, height: 460))
            credits.layoutSubtreeIfNeeded()
            let document = try XCTUnwrap(credits.scroll.documentView)
            XCTAssertGreaterThan(document.bounds.height, credits.scroll.contentSize.height)
            XCTAssertTrue(document.subviews.allSatisfy { document.bounds.contains($0.frame) && $0.frame.width <= 680 })
            let labels = document.subviews.compactMap { $0 as? GameLabel }.map(\.stringValue)
            XCTAssertTrue(labels.contains("Programming: Dave Jones"))
            XCTAssertTrue(labels.contains("Animation: Gary Timmons"))
            XCTAssertTrue(labels.contains("Graphics: Scott Johnston"))
            XCTAssertTrue(labels.contains("Music: Brian Johnston and Tim Wright"))
            XCTAssertTrue(labels.contains { $0.contains("reconstruction made for Ultimate Lemmings") })
            for (position, y) in [("top", document.bounds.height - credits.scroll.contentSize.height), ("bottom", CGFloat.zero)] {
                credits.scroll.contentView.scroll(to: CGPoint(x: 0, y: y))
                credits.scroll.reflectScrolledClipView(credits.scroll.contentView)
                let bitmap = try XCTUnwrap(credits.bitmapImageRepForCachingDisplay(in: credits.bounds))
                credits.cacheDisplay(in: credits.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("heritage-\(Int(width))-\(position).png"))
            }
        }
    }

    @MainActor func testReleaseSelectionKeepsNotesAndTargetsReachableAfterResizing() throws {
        let markdown = (0..<30).map { index in
            "# Release \(index) · Build \(92 - index)\n\n## Changes\n\n"
                + (0..<12).map { "- Improvement \($0) keeps the current player and saved session together." }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        let history = AboutHistoryView(markdown: markdown)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 992, height: 460),
            styleMask: [], backing: .buffered, defer: false)
        window.contentView = history
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/2.0.8-about-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let index = try XCTUnwrap(history.indexScroll.documentView)
        let buttons = index.subviews.compactMap { $0 as? NSButton }
        for width: CGFloat in [772, 992, 1472] {
            window.setContentSize(CGSize(width: width, height: 460))
            history.layoutSubtreeIfNeeded()
            XCTAssertEqual(buttons.count, 30)
            for button in buttons {
                XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                XCTAssertTrue(index.bounds.contains(button.frame))
            }
            let current = try XCTUnwrap(buttons.first)
            XCTAssertTrue(current.accessibilityPerformPress())
            history.layoutSubtreeIfNeeded()
            XCTAssertEqual(history.selectedIndex, 0)
            XCTAssertEqual(current.state, .on)
            let notes = try XCTUnwrap(history.detail.scroll.documentView)
            XCTAssertEqual(notes.bounds.width, history.detail.scroll.contentSize.width, accuracy: 1)
            XCTAssertTrue(notes.subviews.allSatisfy { notes.bounds.contains($0.frame) && $0.frame.width <= 680 })
            let oldest = try XCTUnwrap(buttons.last)
            history.indexScroll.contentView.scroll(to: .zero)
            history.indexScroll.reflectScrolledClipView(history.indexScroll.contentView)
            let target = oldest.convert(oldest.bounds, to: history)
            XCTAssertTrue(history.hitTest(CGPoint(x: target.midX, y: target.midY)) === oldest)
            XCTAssertTrue(oldest.accessibilityPerformPress())
            history.layoutSubtreeIfNeeded()
            XCTAssertEqual(history.selectedIndex, 29)
            XCTAssertEqual(current.state, .off)
            XCTAssertEqual(oldest.state, .on)
            XCTAssertEqual(history.detail.scroll.contentView.bounds.maxY, notes.bounds.maxY, accuracy: 1)
            let bitmap = try XCTUnwrap(history.bitmapImageRepForCachingDisplay(in: history.bounds))
            history.cacheDisplay(in: history.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: output.appendingPathComponent("history-\(Int(width)).png"))
        }
    }
}
#endif
