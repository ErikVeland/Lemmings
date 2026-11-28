import Foundation

public struct DeveloperTipProduct: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let isConsumable: Bool
    public let fallbackDisplayPrice: String?

    public init(id: String, displayName: String, displayPrice: String, isConsumable: Bool = true,
                fallbackDisplayPrice: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.isConsumable = isConsumable
        self.fallbackDisplayPrice = fallbackDisplayPrice
    }

    static func exactFallbackPrice(amount: Decimal, currencyCode: String) -> String? {
        guard currencyCode.utf8.count == 3,
              currencyCode.utf8.allSatisfy({ (65...90).contains($0) }),
              currencyCode != "XXX", currencyCode != "XTS",
              NSLocale.commonISOCurrencyCodes.contains(currencyCode) else { return nil }
        let locale = Locale(identifier: "en_US_POSIX")
        let number = NSDecimalNumber(decimal: amount).description(withLocale: locale)
        guard number.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let parsed = Decimal(string: number, locale: locale), parsed == amount else { return nil }
        return "\(number) \(currencyCode)"
    }
}

public struct DeveloperTipTransaction: Equatable, Sendable {
    public let id: UInt64
    public let productID: String
    public let isConsumable: Bool
    public let isRevoked: Bool

    public init(id: UInt64, productID: String, isConsumable: Bool = true, isRevoked: Bool = false) {
        self.id = id
        self.productID = productID
        self.isConsumable = isConsumable
        self.isRevoked = isRevoked
    }
}

public enum DeveloperTipVerification: Equatable, Sendable {
    case verified(DeveloperTipTransaction)
    case unverified(DeveloperTipTransaction)
}

public enum DeveloperTipPurchaseResult: Equatable, Sendable {
    case success(DeveloperTipVerification)
    case pending
    case cancelled
}

public enum DeveloperTipFailure: Equatable, Sendable {
    case loading
    case purchase
    case verification
}

public enum DeveloperTipState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case purchasing
    case pending
    case purchased
    case cancelled
    case unavailable
    case failed(DeveloperTipFailure)
}

@MainActor public protocol DeveloperTipStoreClient: AnyObject, Sendable {
    var canMakePayments: Bool { get }
    func loadProduct(id: String) async throws -> DeveloperTipProduct?
    func purchase(productID: String) async throws -> DeveloperTipPurchaseResult
    func updates() -> AsyncStream<DeveloperTipVerification>
    func unfinished() -> AsyncStream<DeveloperTipVerification>
    func finish(transactionID: UInt64) async
}

@MainActor public protocol DeveloperTipPreferences: AnyObject, Sendable {
    func wasAcknowledged(transactionID: UInt64) -> Bool
    func acknowledge(transactionID: UInt64)
}

@MainActor public final class DeveloperTipService {
    public nonisolated static let productID = "academy.glasscode.ultimatelemmix.tip"
    public static let shared = DeveloperTipService()

    public private(set) var state: DeveloperTipState = .idle
    public private(set) var product: DeveloperTipProduct?
    public var onChange: (@MainActor () -> Void)?

    public var canPurchase: Bool {
        guard product != nil, client.canMakePayments, !loadingProduct,
              purchaseTask == nil, finishingTransactions.isEmpty,
              unresolvedTransactions.isEmpty else { return false }
        switch state {
        case .ready, .purchased, .cancelled, .failed(.purchase): return true
        default: return false
        }
    }

    private let client: any DeveloperTipStoreClient
    private let preferences: any DeveloperTipPreferences
    private var updatesTask: Task<Void, Never>?
    private var unfinishedTask: Task<Void, Never>?
    private var purchaseTask: Task<Void, Never>?
    private var loadingProduct = false
    private var loadGeneration = 0
    private var stateBeforeLoading: DeveloperTipState?
    private var transactionRevision = 0
    private var finishingTransactions: Set<UInt64> = []
    private var finishedTransactions: Set<UInt64> = []
    private var unresolvedTransactions: Set<UInt64> = []
    private var purchaseReceiptsAwaitingFinish: Set<UInt64> = []

    public convenience init() {
        self.init(client: StoreKitDeveloperTipClient(),
                  preferences: UserDefaultsDeveloperTipPreferences(defaults: .standard))
    }

    public init(client: any DeveloperTipStoreClient, preferences: any DeveloperTipPreferences) {
        self.client = client
        self.preferences = preferences
        let updates = client.updates()
        let unfinished = client.unfinished()
        updatesTask = Task { @MainActor [weak self] in
            for await verification in updates {
                guard !Task.isCancelled, let self else { return }
                await self.receive(verification, fromPurchase: false)
            }
        }
        unfinishedTask = Task { @MainActor [weak self] in
            for await verification in unfinished {
                guard !Task.isCancelled, let self else { return }
                await self.receive(verification, fromPurchase: false)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        unfinishedTask?.cancel()
    }

    public func loadProduct() async {
        guard !Task.isCancelled, purchaseTask == nil else { return }
        loadGeneration += 1
        let generation = loadGeneration
        loadingProduct = true
        switch state {
        case .pending, .purchased, .failed(.verification): break
        case .loading: break
        default:
            stateBeforeLoading = state
            state = .loading
        }
        onChange?()
        guard client.canMakePayments else {
            completeLoad(nil, generation: generation, failed: false)
            return
        }
        do {
            let loaded = try await client.loadProduct(id: Self.productID)
            guard generation == loadGeneration else { return }
            guard !Task.isCancelled else {
                cancelLoad(generation: generation)
                return
            }
            let valid = loaded.map {
                $0.id == Self.productID && $0.isConsumable
                    && !$0.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.displayPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } ?? false
            completeLoad(valid ? loaded : nil, generation: generation, failed: false)
        } catch {
            if error is CancellationError || Task.isCancelled {
                cancelLoad(generation: generation)
            } else {
                completeLoad(nil, generation: generation, failed: true)
            }
        }
    }

    public func purchase() async {
        guard !Task.isCancelled, purchaseTask == nil, canPurchase else { return }
        state = .purchasing
        onChange?()
        let revision = transactionRevision
        let task = Task { @MainActor [self] in
            defer {
                purchaseTask = nil
                onChange?()
            }
            do {
                let result = try await client.purchase(productID: Self.productID)
                switch result {
                case .success(let verification):
                    await receive(verification, fromPurchase: true)
                case .pending:
                    if transactionRevision == revision { state = .pending }
                case .cancelled:
                    if transactionRevision == revision { state = .cancelled }
                }
            } catch {
                if transactionRevision == revision {
                    state = error is CancellationError ? .cancelled : .failed(.purchase)
                }
            }
        }
        purchaseTask = task
        await task.value
    }

    private func completeLoad(_ loaded: DeveloperTipProduct?, generation: Int, failed: Bool) {
        guard generation == loadGeneration else { return }
        product = loaded
        loadingProduct = false
        stateBeforeLoading = nil
        if state == .loading {
            state = failed ? .failed(.loading) : (loaded == nil ? .unavailable : .ready)
        }
        onChange?()
    }

    private func cancelLoad(generation: Int) {
        guard generation == loadGeneration else { return }
        loadingProduct = false
        if state == .loading { state = stateBeforeLoading ?? .idle }
        stateBeforeLoading = nil
        onChange?()
    }

    private func receive(_ verification: DeveloperTipVerification, fromPurchase: Bool) async {
        let transaction: DeveloperTipTransaction
        switch verification {
        case .verified(let value): transaction = value
        case .unverified(let value):
            guard fromPurchase || value.productID == Self.productID else { return }
            guard !finishingTransactions.contains(value.id), !finishedTransactions.contains(value.id) else { return }
            recordVerificationFailure(transactionID: value.id)
            return
        }
        guard transaction.productID == Self.productID, transaction.isConsumable, !transaction.isRevoked else {
            if fromPurchase { recordVerificationFailure(transactionID: transaction.id) }
            return
        }
        let resolvedVerification = unresolvedTransactions.remove(transaction.id) != nil
        if finishedTransactions.contains(transaction.id) {
            if (fromPurchase || resolvedVerification) && unresolvedTransactions.isEmpty {
                state = .purchased
                onChange?()
            }
            return
        }
        if finishingTransactions.contains(transaction.id) {
            if fromPurchase { purchaseReceiptsAwaitingFinish.insert(transaction.id) }
            return
        }
        finishingTransactions.insert(transaction.id)
        let acknowledged = preferences.wasAcknowledged(transactionID: transaction.id)
        if !acknowledged { preferences.acknowledge(transactionID: transaction.id) }
        if !acknowledged || resolvedVerification { transactionRevision += 1 }
        let revision = transactionRevision
        onChange?()
        await client.finish(transactionID: transaction.id)
        finishingTransactions.remove(transaction.id)
        finishedTransactions.insert(transaction.id)
        let requestedReceipt = purchaseReceiptsAwaitingFinish.remove(transaction.id) != nil
        if (!acknowledged || fromPurchase || resolvedVerification || requestedReceipt)
            && transactionRevision == revision && unresolvedTransactions.isEmpty {
            state = .purchased
        }
        onChange?()
    }

    private func recordVerificationFailure(transactionID: UInt64) {
        unresolvedTransactions.insert(transactionID)
        transactionRevision += 1
        state = .failed(.verification)
        onChange?()
    }
}

@MainActor private final class UserDefaultsDeveloperTipPreferences: DeveloperTipPreferences {
    private let defaults: UserDefaults
    private let key = "UltimateLemmix.acknowledgedDeveloperTips"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func wasAcknowledged(transactionID: UInt64) -> Bool {
        defaults.stringArray(forKey: key)?.contains(String(transactionID)) == true
    }

    func acknowledge(transactionID: UInt64) {
        var identifiers = Set(defaults.stringArray(forKey: key) ?? [])
        identifiers.insert(String(transactionID))
        defaults.set(identifiers.sorted(), forKey: key)
    }
}
