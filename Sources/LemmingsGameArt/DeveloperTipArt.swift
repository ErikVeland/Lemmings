import Foundation
import LemmingsAppCore
import NxlvKit

public enum DeveloperTipArt {
    public static var action: GameFrontEnd.Action {
        .init("aboutTip", L10n.text("Leave a tip"))
    }

    public static func page(state: DeveloperTipState, product: DeveloperTipProduct?,
                            canPurchase: Bool) -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("Leave a tip"),
            details: [L10n.text("An optional tip to support development.")],
            footer: [.init("developerTip.back", L10n.text("Back"), backNavigation: true)])
        page.reading = true
        var offersPurchase = false
        var offersRetry = false
        switch state {
        case .idle, .loading:
            page.subtitle = L10n.text("Loading...")
        case .ready:
            offersPurchase = true
        case .purchasing:
            page.subtitle = L10n.text("Purchasing...")
        case .pending:
            page.subtitle = L10n.text("Awaiting approval")
        case .purchased:
            page.subtitle = L10n.text("Thank you for your support!")
            offersPurchase = true
        case .cancelled:
            offersPurchase = true
        case .unavailable, .failed(.loading):
            page.subtitle = L10n.text("Tips are unavailable right now.")
            offersRetry = true
        case .failed(.purchase):
            page.subtitle = L10n.text("Your tip could not be completed.")
            offersRetry = true
        case .failed(.verification):
            page.subtitle = L10n.text("Your tip could not be confirmed.")
        }
        if offersPurchase, canPurchase, let product {
            if let price = renderablePrice(product) {
                let repeated = state == .purchased
                page.footer.append(.init(repeated ? "developerTip.buyAgain" : "developerTip.buy",
                    repeated ? L10n.text("Tip again \(price)") : L10n.text("Tip \(price)"), primary: true))
            } else {
                let unavailable = L10n.text("Tips are unavailable right now.")
                if state == .purchased { page.details.append(unavailable) }
                else { page.subtitle = unavailable }
                offersRetry = true
            }
        }
        if offersRetry {
            page.footer.append(.init("developerTip.retry", L10n.text("Retry"), primary: true))
        }
        return page
    }

    private static func renderablePrice(_ product: DeveloperTipProduct) -> String? {
        for price in [product.displayPrice, product.fallbackDisplayPrice].compactMap({ $0 }) {
            let plain = GameMenuTypography.menuText(price)
            guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !plain.contains("?") else { continue }
            let covered = BitmapTamilGlyphs.sequences(in: plain).allSatisfy {
                $0 == " " || GamePixelTypography.bitmapGlyph(forSequence: $0) != nil
            }
            if covered { return price }
        }
        return nil
    }
}
