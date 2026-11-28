# Developer tips in Ultimate Lemmix

The 2.7.6 candidate adds an optional, repeatable tip through StoreKit for
Ultimate Lemmix on the Mac App Store, iPhone, iPad and Apple TV. Source integration
does not establish that the product is configured, approved or available to buy.

## Product contract

| Setting | Value |
| --- | --- |
| Product ID | `academy.glasscode.ultimatelemmix.tip` |
| Type | Consumable; one payment per explicitly confirmed purchase |
| Entry point | About → Leave a tip |
| Price | Apple's localised `Product.displayPrice`, with an exact StoreKit amount and ISO currency code as the bitmap fallback |
| Benefits | Optional support for development; no content, currency, feature or entitlement is granted |
| Repeat purchase | A new priced action after a completed tip; no recurring payment |

The fallback is used only when the bitmap font cannot display the localised
price. It preserves the amount and currency without conversion or rounding.
Neither price is hardcoded; an unreadable price must not offer a purchase action.

Store builds use the in-app tip page for support actions, including legacy
support routes. Unavailable tips do not redirect to an external coffee page or
payment QR code. Ultimate Lemmings retains its separate direct Mac coffee link.
This is the chosen Store support flow; Apple's external-purchase rules vary by
storefront, and this implementation does not depend on those exceptions.

The service accepts only verified, non-revoked consumable transactions for the
exact product ID. It records acknowledged transaction IDs to avoid duplicate
handling and recovers unfinished transactions. Those records confer no purchase
entitlement. Pending approval or unresolved verification prevents another tip;
reopening the page does not initiate a purchase.

## Configuration still required

No price has been selected or configured as part of this change. App Store
Connect product and account records have not been inspected or modified for
this feature. Product creation, pricing, territories, metadata, active payment
agreements, banking and tax readiness therefore remain unverified. Native
StoreKit testing, sandbox purchases and App Review approval are also outstanding.

## App Store Connect setup and first submission

1. Select the existing **Ultimate Lemmix** app. Confirm its iOS, macOS and tvOS
   versions belong to the same App Store Connect app record before sharing this
   product across them. Matching bundle identifier text alone does not establish
   that relationship; purchases cannot be shared between different app records.
2. The Account Holder must accept the current **Paid Apps Agreement** under
   **Business**, with the required banking and tax information complete. Confirm
   the agreement is **Active**; Apple requires this for sandbox testing too.
3. Under **Monetization → In-App Purchases**, add a **Consumable**, using the exact
   product ID above. A suitable internal reference name is **Developer tip**.
   Check the ID before saving: Apple does not permit changing or reusing it.
4. Add localised product metadata. The display name must be 2–30 characters and
   the description at most 45. Suggested English text is **Developer tip** and
   **Optional support for ongoing development.** The owner must select the price,
   countries or regions and appropriate tax category in App Store Connect.
5. Upload an App Review screenshot showing the tip page and its priced action.
   In review notes, give the About → Leave a tip route and explain that the tip
   is optional, repeatable and grants no content or features. The separate
   1024 × 1024 promotional image is not required for an unpromoted tip.
6. Complete the native and sandbox checks below. Product metadata changes may
   take up to one hour to reach sandbox. Confirm the product reaches **Ready for
   Review**, and select the matching signed Ultimate Lemmix candidate build.
7. If this is the app's first consumable, use **Add for Review** to include both
   this product and the new **2.7.6** app version in the same draft submission,
   then **Submit for Review**. A previously approved purchase of another type
   does not remove the first-consumable requirement. Record product approval
   and each platform's release status separately.

## Validation before enabling purchases

Source review covered exact-product filtering, verified-only finishing, receipt
deduplication, cancellation, delayed transaction results, page lifecycle and
Store support routing. Focused fake-store and isolated UI regressions were
added. These checks have **not been compiled or executed with Apple SDKs** in
the Linux preparation environment; source review is not a native test pass.

- [ ] Build the affected Mac, iOS and tvOS Store targets with the supported Apple
  toolchain and correct Lemmix product conditions, identifiers and signing.
- [ ] Run the focused developer-tip service and UI tests with isolated
  preferences. Follow the repository's headless, offscreen and muted test policy.
  Cover pending and unverified receipts, delayed outcomes, duplicate recovery,
  Back during purchase and a separate explicit action for a second tip.
- [ ] Inspect the actual priced bitmap controls and accessibility labels for
  each enabled storefront, including currency symbols, decimal separators and
  spacing. Neither missing glyphs nor truncation may alter the displayed price.
  Verify touch, keyboard, controller and Apple TV focus targets.
- [ ] With a Sandbox Apple Account, fetch the configured product on each shipping
  platform and compare its price with Apple's purchase sheet. Complete one tip,
  then a separately confirmed second tip, without production charges.
- [ ] Check cancellation, unavailable metadata, network failure, payment
  restrictions, pending approval and recovery after leaving or relaunching.
  Use StoreKit testing or the isolated fake client for states that sandbox cannot
  reliably reproduce, including unverified and out-of-order receipts.
- [ ] Verify that Store support routes never offer external-payment fallback,
  and that the direct Mac Ultimate Lemmings support route remains separate.
- [ ] Record the source revision, native build results, sandbox evidence and
  App Review outcome before describing tips as available in a released build.

## Apple references

Official sources checked on 28 November 2026:

- App Review Guidelines, 3.1.1 and 3.1.1(a) — https://developer.apple.com/app-store/review/guidelines/
- Product.displayPrice — https://developer.apple.com/documentation/storekit/product/displayprice
- Overview for configuring In-App Purchases — https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/
- Sign and update agreements — https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/
- Create consumable or non-consumable In-App Purchases — https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/
- In-App Purchase information — https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/
- Configure In-App Purchases for review in the sandbox — https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases
- Submit an In-App Purchase — https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/
