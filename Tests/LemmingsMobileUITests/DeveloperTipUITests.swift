#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import LemmingsAppCore
import LemmingsGameArt
@testable import LemmingsMobileUI

@MainActor struct DeveloperTipUITests {
    private var product: DeveloperTipProduct {
        .init(id: DeveloperTipService.productID, displayName: "Developer tip", displayPrice: "12,34 kr")
    }

    @Test func tipPageUsesTheStorePriceAndOnlyOffersValidActions() throws {
        let ready = DeveloperTipArt.page(state: .ready, product: product, canPurchase: true)
        let purchase = try #require(ready.footer.first { $0.id == "developerTip.buy" })
        #expect(purchase.title.contains(product.displayPrice))
        #expect(purchase.primary)
        #expect(ready.backAction?.id == "developerTip.back")
        #expect(!ready.preview)

        for state in [DeveloperTipState.idle, .loading, .purchasing, .pending, .unavailable,
                      .failed(.loading), .failed(.purchase), .failed(.verification)] {
            let page = DeveloperTipArt.page(state: state, product: product, canPurchase: true)
            #expect(!page.footer.contains { $0.id == "developerTip.buy" || $0.id == "developerTip.buyAgain" })
            #expect(page.footer.filter(\.primary).count <= 1)
            #expect(page.backAction?.id == "developerTip.back")
            #expect(!page.subtitle.isEmpty)
        }
        #expect(!DeveloperTipArt.page(state: .ready, product: nil, canPurchase: true).footer.contains { $0.primary })
        #expect(!DeveloperTipArt.page(state: .ready, product: product, canPurchase: false).footer.contains { $0.primary })
        let thanked = DeveloperTipArt.page(state: .purchased, product: product, canPurchase: true)
        let repeated = try #require(thanked.footer.first { $0.id == "developerTip.buyAgain" })
        #expect(repeated.title.contains(product.displayPrice))
        #expect(!thanked.footer.contains { $0.id == "developerTip.buy" })
    }

    @Test func storeSupportCannotBecomeAnExternalPaymentPage() {
        #expect(MobileSupportPolicy.usesTipPage(storeBuild: true, configuration: .preservation))
        #expect(MobileSupportPolicy.usesTipPage(storeBuild: false, configuration: .ultimateLemmix))
        let storePolicy = MobileSupportPolicy.usesTipPage(storeBuild: true, configuration: .preservation)
        #expect(MobileSupportPolicy.settingsActions(usesTipPage: storePolicy).map(\.id) == ["about", "whatsNew"])
        #expect(MobileSupportPolicy.settingsActions(usesTipPage: false).map(\.id) == ["about", "whatsNew", "donate"])
        let about = MobileAboutArt.page(productName: "Ultimate Lemmix", version: "2.7.6", build: "117",
            showsLixCredits: true, showsSupportAction: true, showsTipAction: true)
        #expect(about.footer.contains { $0.id == "aboutTip" })
        #expect(!about.footer.contains { $0.id == "donate" })
        for state in [DeveloperTipState.loading, .unavailable, .failed(.loading), .pending, .failed(.verification)] {
            let tip = DeveloperTipArt.page(state: state, product: nil, canPurchase: false)
            let support = MobileSupportPage(tipPage: tip, returningToAbout: true)
            #expect(support.preview == nil)
            #expect(!support.page.preview)
            #expect(!support.page.details.joined().contains("coff.ee"))
            #expect(support.page.backAction?.id == "developerTip.back")
        }
        #expect(MobileAboutArt.forumsPage.preview)
        #expect(MobileAboutArt.forumsPage.footer.contains { $0.id == "aboutForumsBack" })
    }

    @Test func visiblePriceTargetAcceptsInputAndRejectsStalePurchaseActions() async throws {
        let store = TipUIStore(product: product)
        let service = DeveloperTipService(client: store, preferences: TipUIPreferences())
        let state = MobileDeveloperTipState(service: service)
        let canvas = MobileMenuCanvas()
        var active = true
        var accepted: [String] = []
        defer {
            state.end()
            store.resolve(.cancelled)
        }
        canvas.onAction = { [weak state] id in
            if state?.handle(id) == true { accepted.append(id) }
        }
        state.begin(isActive: { active }, onChange: { [weak state] in
            if let state { canvas.page = state.page }
        })
        let loading = try #require(state.task)
        await loading.value
        canvas.frame = CGRect(origin: .zero, size: canvas.size(width: 390, minimumHeight: 700))
        canvas.layoutIfNeeded()
        let button = try #require(canvas.subviews.first { $0.accessibilityIdentifier == "menu.developerTip.buy" } as? UIButton)
        #expect(button.accessibilityLabel?.contains(product.displayPrice) == true)
        #expect(canvas.hitTest(CGPoint(x: button.frame.midX, y: button.frame.midY), with: nil) === button)
        canvas.focusAction("developerTip.buy")
        canvas.activateFocused()
        try await waitUntil { store.purchaseRequests == 1 }
        #expect(accepted == ["developerTip.buy"])
        store.resolve(.pending)
        try await waitUntil { service.state == .pending }
        button.sendActions(for: .gameActivation)
        #expect(accepted == ["developerTip.buy"])
        #expect(store.purchaseRequests == 1)
        active = false
        state.end()
        canvas.page = .init(title: "About")
        button.sendActions(for: .gameActivation)
        #expect(accepted == ["developerTip.buy"])
    }

    @Test func completingAfterBackFinishesTheTipWithoutRepaintingAnotherRoute() async throws {
        let store = TipUIStore(product: product)
        let service = DeveloperTipService(client: store, preferences: TipUIPreferences())
        let state = MobileDeveloperTipState(service: service)
        var active = true
        var changes = 0
        defer {
            state.end()
            store.resolve(.cancelled)
        }
        state.begin(isActive: { active }, onChange: { changes += 1 })
        let loading = try #require(state.task)
        await loading.value
        #expect(state.handle("developerTip.buy"))
        try await waitUntil { store.purchaseRequests == 1 }
        active = false
        state.end()
        let previousChanges = changes
        store.resolve(.success(.verified(.init(id: 42, productID: DeveloperTipService.productID))))
        try await waitUntil { service.state == .purchased && service.canPurchase }
        #expect(store.finished == [42])
        #expect(changes == previousChanges)
        #expect(!state.handle("developerTip.buyAgain"))
        active = true
        state.begin(isActive: { active }, onChange: { changes += 1 })
        let reopened = try #require(state.task)
        await reopened.value
        #expect(state.page.footer.contains { $0.id == "developerTip.buyAgain" })
        #expect(!state.handle("developerTip.buy"))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !condition() {
            try #require(ProcessInfo.processInfo.systemUptime < deadline)
            await Task.yield()
        }
    }
}

@MainActor private final class TipUIStore: DeveloperTipStoreClient {
    let product: DeveloperTipProduct
    var canMakePayments = true
    private var pending: CheckedContinuation<DeveloperTipPurchaseResult, Error>?
    private(set) var purchaseRequests = 0
    private(set) var finished: [UInt64] = []

    init(product: DeveloperTipProduct) {
        self.product = product
    }

    func loadProduct(id: String) async throws -> DeveloperTipProduct? { product }

    func purchase(productID: String) async throws -> DeveloperTipPurchaseResult {
        purchaseRequests += 1
        return try await withCheckedThrowingContinuation { pending = $0 }
    }

    func updates() -> AsyncStream<DeveloperTipVerification> { AsyncStream { $0.finish() } }
    func unfinished() -> AsyncStream<DeveloperTipVerification> { AsyncStream { $0.finish() } }
    func finish(transactionID: UInt64) async { finished.append(transactionID) }

    func resolve(_ result: DeveloperTipPurchaseResult) {
        let response = pending
        pending = nil
        response?.resume(returning: result)
    }
}

@MainActor private final class TipUIPreferences: DeveloperTipPreferences {
    private var acknowledged: Set<UInt64> = []
    func wasAcknowledged(transactionID: UInt64) -> Bool { acknowledged.contains(transactionID) }
    func acknowledge(transactionID: UInt64) { acknowledged.insert(transactionID) }
}
#endif
