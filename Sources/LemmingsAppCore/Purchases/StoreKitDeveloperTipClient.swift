import Foundation

#if canImport(StoreKit)
import StoreKit

@MainActor final class StoreKitDeveloperTipClient: DeveloperTipStoreClient {
    var canMakePayments: Bool { AppStore.canMakePayments }

    private var product: Product?
    private var loadGeneration = 0
    private var transactions: [UInt64: StoreKit.Transaction] = [:]
    private var finishedTransactions: Set<UInt64> = []

    func loadProduct(id: String) async throws -> DeveloperTipProduct? {
        guard id == DeveloperTipService.productID else { return nil }
        loadGeneration += 1
        let generation = loadGeneration
        let products = try await Product.products(for: [id])
        let loaded = products.first { $0.id == id && $0.type == .consumable }
        if generation == loadGeneration && !Task.isCancelled { product = loaded }
        return loaded.map {
            DeveloperTipProduct(id: $0.id, displayName: $0.displayName,
                                displayPrice: $0.displayPrice, isConsumable: $0.type == .consumable,
                                fallbackDisplayPrice: DeveloperTipProduct.exactFallbackPrice(
                                    amount: $0.price, currencyCode: $0.priceFormatStyle.currencyCode))
        }
    }

    func purchase(productID: String) async throws -> DeveloperTipPurchaseResult {
        guard canMakePayments, productID == DeveloperTipService.productID,
              let product, product.id == productID, product.type == .consumable else {
            throw ClientFailure.unavailable
        }
        switch try await product.purchase() {
        case .success(let result): return .success(convert(result))
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw ClientFailure.unknownPurchaseResult
        }
    }

    func updates() -> AsyncStream<DeveloperTipVerification> {
        stream(StoreKit.Transaction.updates)
    }

    func unfinished() -> AsyncStream<DeveloperTipVerification> {
        stream(StoreKit.Transaction.unfinished)
    }

    func finish(transactionID: UInt64) async {
        guard let transaction = transactions[transactionID],
              transaction.productID == DeveloperTipService.productID,
              transaction.productType == .consumable, transaction.revocationDate == nil else { return }
        await transaction.finish()
        transactions.removeValue(forKey: transactionID)
        finishedTransactions.insert(transactionID)
    }

    private func stream(_ sequence: StoreKit.Transaction.Transactions) -> AsyncStream<DeveloperTipVerification> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                for await result in sequence {
                    guard !Task.isCancelled, let self else { break }
                    continuation.yield(self.convert(result))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func convert(_ result: VerificationResult<StoreKit.Transaction>) -> DeveloperTipVerification {
        switch result {
        case .verified(let transaction):
            let value = snapshot(transaction)
            if value.productID == DeveloperTipService.productID && value.isConsumable
                && !value.isRevoked && !finishedTransactions.contains(value.id) {
                transactions[value.id] = transaction
            }
            return .verified(value)
        case .unverified(let transaction, _):
            return .unverified(snapshot(transaction))
        }
    }

    private func snapshot(_ transaction: StoreKit.Transaction) -> DeveloperTipTransaction {
        DeveloperTipTransaction(id: transaction.id, productID: transaction.productID,
                                isConsumable: transaction.productType == .consumable,
                                isRevoked: transaction.revocationDate != nil)
    }

    private enum ClientFailure: Error {
        case unavailable
        case unknownPurchaseResult
    }
}
#else
@MainActor final class StoreKitDeveloperTipClient: DeveloperTipStoreClient {
    var canMakePayments: Bool { false }
    func loadProduct(id: String) async throws -> DeveloperTipProduct? { nil }
    func purchase(productID: String) async throws -> DeveloperTipPurchaseResult { .cancelled }
    func updates() -> AsyncStream<DeveloperTipVerification> { AsyncStream { $0.finish() } }
    func unfinished() -> AsyncStream<DeveloperTipVerification> { AsyncStream { $0.finish() } }
    func finish(transactionID: UInt64) async {}
}
#endif
