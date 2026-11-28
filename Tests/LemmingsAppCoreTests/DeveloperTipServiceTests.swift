import Foundation
import Testing
@testable import LemmingsAppCore

@MainActor private final class TipTestPreferences: DeveloperTipPreferences {
    var acknowledged: Set<UInt64>
    var writes: [UInt64] = []

    init(acknowledged: Set<UInt64> = []) {
        self.acknowledged = acknowledged
    }

    func wasAcknowledged(transactionID: UInt64) -> Bool { acknowledged.contains(transactionID) }

    func acknowledge(transactionID: UInt64) {
        writes.append(transactionID)
        acknowledged.insert(transactionID)
    }
}

@MainActor private final class TipTestStore: DeveloperTipStoreClient {
    var canMakePayments = true
    var offeredProduct: DeveloperTipProduct? = .init(id: DeveloperTipService.productID,
        displayName: "Store-localised tip name", displayPrice: "Store-localised price")
    var result: DeveloperTipPurchaseResult = .cancelled
    var loadError = false
    var purchaseError = false
    var loadHandler: (@MainActor (Int) async throws -> DeveloperTipProduct?)?
    var purchaseHandler: (@MainActor () async throws -> DeveloperTipPurchaseResult)?
    var finishHandler: (@MainActor (UInt64) async -> Void)?
    var loadRequests: [String] = []
    var purchaseRequests: [String] = []
    var finishes: [UInt64] = []
    var updatesTerminated = false
    private let updateStream: AsyncStream<DeveloperTipVerification>
    private let updateContinuation: AsyncStream<DeveloperTipVerification>.Continuation
    private let unfinishedStream: AsyncStream<DeveloperTipVerification>

    init(unfinished: [DeveloperTipVerification] = []) {
        var updateSink: AsyncStream<DeveloperTipVerification>.Continuation?
        updateStream = AsyncStream { updateSink = $0 }
        updateContinuation = updateSink!
        unfinishedStream = AsyncStream { continuation in
            for value in unfinished { continuation.yield(value) }
            continuation.finish()
        }
        updateContinuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.updatesTerminated = true }
        }
    }

    func loadProduct(id: String) async throws -> DeveloperTipProduct? {
        loadRequests.append(id)
        if loadError { throw InjectedFailure.failed }
        if let loadHandler { return try await loadHandler(loadRequests.count) }
        return offeredProduct
    }

    func purchase(productID: String) async throws -> DeveloperTipPurchaseResult {
        purchaseRequests.append(productID)
        if purchaseError { throw InjectedFailure.failed }
        if let purchaseHandler { return try await purchaseHandler() }
        return result
    }

    func updates() -> AsyncStream<DeveloperTipVerification> { updateStream }
    func unfinished() -> AsyncStream<DeveloperTipVerification> { unfinishedStream }
    func finish(transactionID: UInt64) async {
        finishes.append(transactionID)
        await finishHandler?(transactionID)
    }
    func send(_ result: DeveloperTipVerification) { updateContinuation.yield(result) }

    private enum InjectedFailure: Error { case failed }
}

@MainActor struct DeveloperTipServiceTests {
    @Test func fallbackPricePreservesExactDecimalAndCurrency() throws {
        let prices = [("4.99", "EUR"), ("300", "JPY"), ("1.234", "BHD"),
                      ("12345678901234567890.123456789", "USD"), ("0", "GBP")]
        for (number, currency) in prices {
            let amount = try #require(Decimal(string: number, locale: Locale(identifier: "en_US_POSIX")))
            #expect(DeveloperTipProduct.exactFallbackPrice(amount: amount, currencyCode: currency)
                == "\(number) \(currency)")
        }
    }

    @Test func fallbackPriceRejectsInvalidAmountsAndCurrencyCodes() {
        for code in ["", "US", "USDD", "usd", " USD", "USD ", "US$", "ZZZ", "XXX", "XTS", "د.إ"] {
            #expect(DeveloperTipProduct.exactFallbackPrice(amount: Decimal(1), currencyCode: code) == nil)
        }
        #expect(DeveloperTipProduct.exactFallbackPrice(amount: Decimal(-1), currencyCode: "USD") == nil)
        #expect(DeveloperTipProduct.exactFallbackPrice(amount: NSDecimalNumber.notANumber.decimalValue,
            currencyCode: "USD") == nil)
    }

    @Test func cataloguePreservesStorePriceAlongsideFallback() async {
        let client = TipTestStore()
        client.offeredProduct = .init(id: DeveloperTipService.productID,
            displayName: "Store-localised tip name", displayPrice: "٤٫٩٩ د.إ.",
            fallbackDisplayPrice: "4.99 AED")
        let service = DeveloperTipService(client: client, preferences: TipTestPreferences())
        await service.loadProduct()
        #expect(service.product?.displayPrice == "٤٫٩٩ د.إ.")
        #expect(service.product?.fallbackDisplayPrice == "4.99 AED")
        #expect(client.purchaseRequests.isEmpty)
    }

    private func transaction(_ id: UInt64, productID: String = DeveloperTipService.productID,
                             isConsumable: Bool = true, isRevoked: Bool = false) -> DeveloperTipTransaction {
        .init(id: id, productID: productID, isConsumable: isConsumable, isRevoked: isRevoked)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            await Task.yield()
        }
        #expect(condition())
    }

    @Test func catalogueUsesOnlyStoreMetadataAndNeverPurchases() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        #expect(client.loadRequests.isEmpty && client.purchaseRequests.isEmpty)
        #expect(service.state == .idle && !service.canPurchase)
        await service.purchase()
        #expect(client.purchaseRequests.isEmpty)
        await service.loadProduct()
        #expect(service.state == .ready && service.canPurchase)
        #expect(service.product == client.offeredProduct)
        #expect(client.loadRequests == [DeveloperTipService.productID])
        #expect(client.purchaseRequests.isEmpty && client.finishes.isEmpty && preferences.writes.isEmpty)
    }

    @Test func missingInvalidOrRestrictedProductsCannotBePurchased() async {
        let products: [DeveloperTipProduct?] = [
            nil,
            .init(id: "another.product", displayName: "Other", displayPrice: "Price"),
            .init(id: DeveloperTipService.productID, displayName: "Subscription", displayPrice: "Price", isConsumable: false),
            .init(id: DeveloperTipService.productID, displayName: "Tip", displayPrice: " "),
            .init(id: DeveloperTipService.productID, displayName: "", displayPrice: "Price")
        ]
        for product in products {
            let client = TipTestStore()
            client.offeredProduct = product
            let service = DeveloperTipService(client: client, preferences: TipTestPreferences())
            await service.loadProduct()
            #expect(service.state == .unavailable && service.product == nil && !service.canPurchase)
            await service.purchase()
            #expect(client.purchaseRequests.isEmpty)
        }
        let restricted = TipTestStore()
        restricted.canMakePayments = false
        let service = DeveloperTipService(client: restricted, preferences: TipTestPreferences())
        await service.loadProduct()
        await service.purchase()
        #expect(service.state == .unavailable && !service.canPurchase)
        #expect(restricted.loadRequests.isEmpty && restricted.purchaseRequests.isEmpty)
    }

    @Test func verifiedTipsFinishOnceAndRemainRepeatable() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        client.result = .success(.verified(transaction(10)))
        await service.purchase()
        #expect(service.state == .purchased && service.canPurchase)
        #expect(preferences.writes == [10] && client.finishes == [10])
        await service.loadProduct()
        #expect(service.state == .purchased && service.canPurchase)
        client.result = .success(.verified(transaction(11)))
        await service.purchase()
        #expect(client.purchaseRequests == [DeveloperTipService.productID, DeveloperTipService.productID])
        #expect(preferences.writes == [10, 11] && client.finishes == [10, 11])
        client.send(.verified(transaction(10)))
        client.send(.verified(transaction(11)))
        client.send(.verified(transaction(12)))
        await waitUntil { client.finishes.contains(12) }
        #expect(preferences.writes == [10, 11, 12] && client.finishes == [10, 11, 12])
    }

    @Test func pendingApprovalSurvivesRefreshAndCompletesThroughUpdates() async {
        let client = TipTestStore()
        client.result = .pending
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        await service.purchase()
        #expect(service.state == .pending && !service.canPurchase)
        await service.loadProduct()
        await service.purchase()
        #expect(service.state == .pending && client.purchaseRequests.count == 1)
        #expect(client.finishes.isEmpty && preferences.writes.isEmpty)
        client.canMakePayments = false
        await service.purchase()
        #expect(service.state == .pending)
        client.send(.verified(transaction(20)))
        await waitUntil { service.state == .purchased }
        #expect(client.finishes == [20] && preferences.writes == [20])
        #expect(!service.canPurchase)
    }

    @Test func cancellationAndStoreFailuresDoNotRecordOrFinishPurchases() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        client.loadError = true
        await service.loadProduct()
        #expect(service.state == .failed(.loading) && !service.canPurchase)
        client.loadError = false
        await service.loadProduct()
        await service.purchase()
        #expect(service.state == .cancelled && service.canPurchase)
        client.purchaseError = true
        await service.purchase()
        #expect(service.state == .failed(.purchase) && service.canPurchase)
        #expect(client.finishes.isEmpty && preferences.writes.isEmpty)
    }

    @Test func unverifiedPurchaseBlocksAnotherChargeAcrossCatalogRefresh() async {
        let client = TipTestStore()
        client.result = .success(.unverified(transaction(30)))
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        await service.purchase()
        #expect(service.state == .failed(.verification) && !service.canPurchase)
        await service.loadProduct()
        await service.purchase()
        #expect(service.state == .failed(.verification) && client.purchaseRequests.count == 1)
        #expect(client.finishes.isEmpty && preferences.writes.isEmpty)
        client.send(.verified(transaction(30)))
        await waitUntil { service.state == .purchased }
        #expect(client.finishes == [30] && preferences.writes == [30])
    }

    @Test func foreignWrongTypeAndRevokedTransactionsAreNeverConsumed() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        client.send(.verified(transaction(40, productID: "another.product")))
        client.send(.verified(transaction(41, isConsumable: false)))
        client.send(.verified(transaction(42, isRevoked: true)))
        client.send(.unverified(transaction(43, productID: "another.product")))
        client.send(.verified(transaction(44)))
        await waitUntil { service.state == .purchased }
        #expect(client.finishes == [44] && preferences.writes == [44])
        client.result = .success(.verified(transaction(45, productID: "another.product")))
        await service.purchase()
        #expect(service.state == .failed(.verification))
        #expect(client.finishes == [44] && preferences.writes == [44])
    }

    @Test func unfinishedRecoveryFinishesAcknowledgedTipsWithoutRecordingAgain() async {
        let preferences = TipTestPreferences(acknowledged: [50])
        let client = TipTestStore(unfinished: [.verified(transaction(50))])
        let service = DeveloperTipService(client: client, preferences: preferences)
        await waitUntil { client.finishes == [50] }
        #expect(preferences.writes.isEmpty)
        #expect(service.state == .idle)
        await service.loadProduct()
        client.send(.verified(transaction(50)))
        client.send(.verified(transaction(51)))
        await waitUntil { service.state == .purchased }
        #expect(client.finishes == [50, 51] && preferences.writes == [51])
    }

    @Test func cancellingTheCallingTaskDoesNotAbandonAnApprovedPurchase() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences()
        var completion: CheckedContinuation<DeveloperTipPurchaseResult, any Error>?
        client.purchaseHandler = {
            try await withCheckedThrowingContinuation { completion = $0 }
        }
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        let caller = Task { await service.purchase() }
        await waitUntil { completion != nil }
        caller.cancel()
        service.onChange = nil
        completion?.resume(returning: .success(.verified(transaction(60))))
        await caller.value
        #expect(service.state == .purchased && service.canPurchase)
        #expect(client.finishes == [60] && preferences.writes == [60])
    }

    @Test func latePurchaseResultCannotOverwriteAnApprovedUpdate() async {
        let client = TipTestStore()
        var completion: CheckedContinuation<DeveloperTipPurchaseResult, any Error>?
        client.purchaseHandler = {
            try await withCheckedThrowingContinuation { completion = $0 }
        }
        let service = DeveloperTipService(client: client, preferences: TipTestPreferences())
        await service.loadProduct()
        let caller = Task { await service.purchase() }
        await waitUntil { completion != nil }
        await service.purchase()
        #expect(client.purchaseRequests.count == 1)
        client.send(.verified(transaction(70)))
        await waitUntil { service.state == .purchased }
        completion?.resume(returning: .pending)
        await caller.value
        #expect(service.state == .purchased && service.canPurchase && client.finishes == [70])
    }

    @Test func latePurchaseOutcomesCannotClearAnUnverifiedUpdate() async {
        for outcome in [DeveloperTipPurchaseResult.cancelled, .pending] {
            let client = TipTestStore()
            let preferences = TipTestPreferences()
            var completion: CheckedContinuation<DeveloperTipPurchaseResult, any Error>?
            client.purchaseHandler = {
                try await withCheckedThrowingContinuation { completion = $0 }
            }
            let service = DeveloperTipService(client: client, preferences: preferences)
            await service.loadProduct()
            let caller = Task { await service.purchase() }
            await waitUntil { completion != nil }
            client.send(.unverified(transaction(71)))
            await waitUntil { service.state == .failed(.verification) }
            completion?.resume(returning: outcome)
            await caller.value
            #expect(service.state == .failed(.verification) && !service.canPurchase)
            #expect(client.finishes.isEmpty && preferences.writes.isEmpty)
        }
        let client = TipTestStore()
        var completion: CheckedContinuation<DeveloperTipPurchaseResult, any Error>?
        client.purchaseHandler = {
            try await withCheckedThrowingContinuation { completion = $0 }
        }
        let service = DeveloperTipService(client: client, preferences: TipTestPreferences())
        await service.loadProduct()
        let caller = Task { await service.purchase() }
        await waitUntil { completion != nil }
        client.send(.unverified(transaction(72)))
        await waitUntil { service.state == .failed(.verification) }
        completion?.resume(throwing: NSError(domain: "DeveloperTipTests", code: 1))
        await caller.value
        #expect(service.state == .failed(.verification) && !service.canPurchase)
    }

    @Test func finishingAnotherTipCannotClearUnresolvedVerification() async {
        let client = TipTestStore()
        var finish: CheckedContinuation<Void, Never>?
        client.finishHandler = { id in
            if id == 73 { await withCheckedContinuation { finish = $0 } }
        }
        client.result = .success(.verified(transaction(73)))
        let preferences = TipTestPreferences()
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        let caller = Task { await service.purchase() }
        await waitUntil { finish != nil }
        client.send(.unverified(transaction(74)))
        await waitUntil { service.state == .failed(.verification) }
        finish?.resume()
        await caller.value
        #expect(service.state == .failed(.verification) && !service.canPurchase)
        #expect(client.finishes == [73] && preferences.writes == [73])
        client.send(.verified(transaction(74)))
        await waitUntil { service.state == .purchased }
        #expect(service.canPurchase && client.finishes == [73, 74])
    }

    @Test func aPurchaseReturningAnAcknowledgedReceiptDoesNotRemainBusy() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences(acknowledged: [75])
        var purchase: CheckedContinuation<DeveloperTipPurchaseResult, any Error>?
        var finish: CheckedContinuation<Void, Never>?
        client.purchaseHandler = {
            try await withCheckedThrowingContinuation { purchase = $0 }
        }
        client.finishHandler = { _ in await withCheckedContinuation { finish = $0 } }
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        let caller = Task { await service.purchase() }
        await waitUntil { purchase != nil }
        client.send(.verified(transaction(75)))
        await waitUntil { finish != nil }
        purchase?.resume(returning: .success(.verified(transaction(75))))
        await caller.value
        #expect(!service.canPurchase)
        finish?.resume()
        await waitUntil { service.state == .purchased }
        #expect(service.canPurchase && client.finishes == [75] && preferences.writes.isEmpty)
        client.purchaseHandler = nil
        client.result = .success(.verified(transaction(75)))
        await service.purchase()
        #expect(service.state == .purchased && service.canPurchase)
        #expect(client.finishes == [75] && preferences.writes.isEmpty)
    }

    @Test func aDifferentApprovedUpdateDoesNotDiscardPurchaseVerificationFailure() async {
        let client = TipTestStore()
        let preferences = TipTestPreferences()
        var completion: CheckedContinuation<DeveloperTipPurchaseResult, any Error>?
        client.purchaseHandler = {
            try await withCheckedThrowingContinuation { completion = $0 }
        }
        let service = DeveloperTipService(client: client, preferences: preferences)
        await service.loadProduct()
        let caller = Task { await service.purchase() }
        await waitUntil { completion != nil }
        client.send(.verified(transaction(76)))
        await waitUntil { service.state == .purchased }
        completion?.resume(returning: .success(.unverified(transaction(77))))
        await caller.value
        #expect(service.state == .failed(.verification) && !service.canPurchase)
        #expect(client.finishes == [76] && preferences.writes == [76])
        client.send(.verified(transaction(78)))
        await waitUntil { client.finishes.contains(78) }
        #expect(service.state == .failed(.verification) && !service.canPurchase)
        client.send(.verified(transaction(77)))
        await waitUntil { service.state == .purchased }
        #expect(service.canPurchase && client.finishes == [76, 78, 77])
        #expect(preferences.writes == [76, 78, 77])
    }

    @Test func staleOrCancelledCatalogResultsDoNotReplaceCurrentMetadata() async {
        let client = TipTestStore()
        let latest = DeveloperTipProduct(id: DeveloperTipService.productID,
            displayName: "Current Store name", displayPrice: "Current Store price")
        var completion: CheckedContinuation<DeveloperTipProduct?, any Error>?
        client.loadHandler = { request in
            if request == 1 {
                return try await withCheckedThrowingContinuation { completion = $0 }
            }
            return latest
        }
        let service = DeveloperTipService(client: client, preferences: TipTestPreferences())
        let stale = Task { await service.loadProduct() }
        await waitUntil { completion != nil }
        await service.loadProduct()
        completion?.resume(returning: client.offeredProduct)
        await stale.value
        #expect(service.product == latest && service.state == .ready && service.canPurchase)
        completion = nil
        client.loadHandler = { _ in
            try await withCheckedThrowingContinuation { completion = $0 }
        }
        let cancelled = Task { await service.loadProduct() }
        await waitUntil { completion != nil }
        cancelled.cancel()
        completion?.resume(returning: client.offeredProduct)
        await cancelled.value
        #expect(service.product == latest && service.state == .ready && service.canPurchase)
    }

    @Test func releasingServiceCancelsTheIndefiniteListener() async {
        let client = TipTestStore()
        var service: DeveloperTipService? = DeveloperTipService(client: client, preferences: TipTestPreferences())
        weak var weakService = service
        await Task.yield()
        service = nil
        await waitUntil { weakService == nil && client.updatesTerminated }
        #expect(weakService == nil)
    }
}
