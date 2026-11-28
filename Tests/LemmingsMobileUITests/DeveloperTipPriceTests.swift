import Foundation
import Testing
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit

@MainActor struct DeveloperTipPriceTests {
    @Test func supportedStorePricesKeepTheirCurrencyAndAmount() throws {
        let prices = [
            ("$1.99", "$1.99"), ("£1.99", "£1.99"), ("1,99\u{00A0}€", "1,99 €"),
            ("¥250", "¥250"), ("￥250", "¥250"), ("₹199.00", "₹199.00"),
            ("R$\u{00A0}9,90", "R$ 9,90"), ("CHF\u{00A0}1’990.00", "CHF 1'990.00"),
            ("12,34 kr", "12,34 KR"), ("4,99 zł", "4,99 ZŁ")
        ]
        for (price, rendered) in prices {
            let product = DeveloperTipProduct(id: DeveloperTipService.productID,
                displayName: "Developer tip", displayPrice: price)
            for state in [DeveloperTipState.ready, .purchased] {
                let page = DeveloperTipArt.page(state: state, product: product, canPurchase: true)
                let action = try #require(page.footer.first { $0.id == purchaseID(state) })
                #expect(action.title.contains(price))
                #expect(GameMenuTypography.menuText(action.title).contains(rendered))
                try requireCompleteBitmapText(action.title)
            }
        }
    }

    @Test func unsupportedStoreFormatsUseOnlyTheExactMetadataFallback() throws {
        let prices = [
            ("\u{200F}٤٫٩٩\u{00A0}ر.س.\u{200F}", "4.99 SAR"),
            ("۹۹٬۰۰۰\u{00A0}ریال", "99000 IRR"), ("৳\u{00A0}১৯৯.০০", "199 BDT"),
            ("฿69.00", "69 THB"), ("\u{200F}₪\u{00A0}7.90", "7.9 ILS"),
            ("₩1,100", "1100 KRW"), ("99,00\u{00A0}₽", "99 RUB")
        ]
        for (price, fallback) in prices {
            let product = DeveloperTipProduct(id: DeveloperTipService.productID,
                displayName: "Developer tip", displayPrice: price, fallbackDisplayPrice: fallback)
            for state in [DeveloperTipState.ready, .purchased] {
                let page = DeveloperTipArt.page(state: state, product: product, canPurchase: true)
                let action = try #require(page.footer.first { $0.id == purchaseID(state) })
                #expect(action.title.contains(fallback))
                #expect(!action.title.contains(price))
                try requireCompleteBitmapText(action.title)
            }
        }
        let product = DeveloperTipProduct(id: DeveloperTipService.productID,
            displayName: "Developer tip", displayPrice: "£1.99", fallbackDisplayPrice: "1.99 GBP")
        let action = try #require(DeveloperTipArt.page(state: .ready, product: product, canPurchase: true)
            .footer.first { $0.id == "developerTip.buy" })
        #expect(action.title.contains("£1.99"))
        #expect(!action.title.contains("GBP"))
    }

    @Test func missingOrUnrenderablePricesNeverOfferAPurchase() {
        let prices: [(String, String?)] = [
            ("₩1,100", nil), ("₩1,100", "١١٠٠ KRW"), ("1.99 ?", "?"), ("", ""), ("\n", "\t")
        ]
        for (price, fallback) in prices {
            let product = DeveloperTipProduct(id: DeveloperTipService.productID,
                displayName: "Developer tip", displayPrice: price, fallbackDisplayPrice: fallback)
            for state in [DeveloperTipState.ready, .cancelled, .purchased] {
                let page = DeveloperTipArt.page(state: state, product: product, canPurchase: true)
                #expect(!page.footer.contains { $0.id == "developerTip.buy" || $0.id == "developerTip.buyAgain" })
                #expect(page.footer.filter(\.primary).map(\.id) == ["developerTip.retry"])
                #expect(page.backAction?.id == "developerTip.back")
                #expect(!page.subtitle.isEmpty)
            }
        }
    }

    private func purchaseID(_ state: DeveloperTipState) -> String {
        state == .purchased ? "developerTip.buyAgain" : "developerTip.buy"
    }

    private func requireCompleteBitmapText(_ text: String) throws {
        let rendered = GameMenuTypography.menuText(text)
        #expect(!rendered.contains("?"))
        for item in GamePixelTypography.layout(rendered) where item.sequence != " " {
            let glyph = try #require(item.glyph)
            #expect(stride(from: 3, to: glyph.rgba.count, by: 4).contains { glyph.rgba[$0] != 0 })
        }
    }
}
