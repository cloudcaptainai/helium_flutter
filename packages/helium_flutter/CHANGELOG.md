## 3.3.10
- Updated Helium Android dependency to 4.5.2

## 3.3.9
- Updated Helium Android dependency to 4.4.9

## 3.3.8
- Updated helium-swift dependency to 4.6.0
- Updated Helium Android dependency to 4.4.8

## 3.3.7
- Added `clearCustomUserId()` to clear the custom user ID set via `overrideUserId`, reverting to Helium's anonymous user ID (e.g. on sign-out). Note that `resetHelium` does not clear the custom user ID.

## 3.3.6
- Added `onEntitled` and `onPaywallUnavailable` callbacks to `presentUpsell`. `onEntitled` fires when the user becomes entitled (purchase, restore, or already-entitled skip when `dontShowIfAlreadyEntitled` is set); `onPaywallUnavailable` fires when neither the paywall nor fallback could be shown.

## 3.3.5
- Updated helium-swift dependency to 4.5.5 and Helium Android dependency to 4.4.7
- Added `getPaddleCustomerId()` and deprecated `createPaddlePortalSession()`. Fetch the Paddle customer ID and pass it to your server to generate a portal session. iOS only.
- Added `setPaywallPreviewsEnabledInDevBuilds(bool)` to toggle the triple-tap paywall previews gesture in dev builds.
- Added `HeliumFlutter().testing` overrides (`setPurchaseResult`, `setRestoreResult`, `setIntroOfferEligibility`, `reset`) for stubbing purchase/restore flows in automated tests.

## 3.3.4
- Updated helium-swift dependency to 4.4.8
- **Breaking:** `handleURL(String url)` now returns `Future<HeliumCheckoutRedirectType?>` instead of `Future<bool>`. Returns the matched redirect type (`success` / `cancel`) when the URL is a Helium checkout redirect, otherwise `null`.

## 3.3.3
- Updated helium-swift dependency to 4.4.4

## 3.3.2
- Updated Helium Android dependency to 4.4.1

## 3.3.1
- Updated helium-swift dependency to 4.4.1

## 3.3.0
- Added `handleURL(String url)` for forwarding External Web Checkout redirect URLs to Helium (iOS only).
- Exposed new event fields on `HeliumPaywallEvent`: `loadTimeTakenMS`, `loadingBudgetMS`, `totalInitializeTimeMS`, `skipReason`, `origin`.
- Added `PaywallSkippedReason` and `PurchaseRestoredOrigin` enums.
- Added `loadTimeTakenMS`, `loadingBudgetMS`, and `paywallUnavailableReason` to `PaywallOpenEvent` / `PaywallOpenFailedEvent` typed events.

## 3.2.7
- Updated helium-swift dependency to 4.4.0

## 3.2.6
- Updated helium-swift dependency to 4.3.0

## 3.2.5
- Updated helium-swift dependency to 4.2.0

## 3.2.4
- Update Helium Android dependency. Add support for iOS Stripe.

## 3.2.3
- Updated helium-swift dependency to 4.1.8

## 3.2.2
- Updated helium-swift dependency to 4.1.6

## 3.2.1
- Updated helium-swift dependency to 4.1.4

## 3.2.0
- Updated helium-swift dependency to 4.1.2 & helium-android to 4.0.1

## 3.1.3
- Updated helium-swift dependency to 3.1.6

## 3.1.2
- Updated helium-swift dependency to 3.1.4

## 3.1.1
- Updated Helium Android dependency to 0.1.21

## 3.1.0
- Android beta support

## 3.0.18
- Avoid sporadic crash from new downloadStatus logic

## 3.0.17
- Updated helium-swift dependency to 3.1.2

## 3.0.16
- Updated helium-swift dependency to 3.1.1

## 3.0.15
- Updated helium-swift dependency to 3.0.15

## 3.0.12
- Updated helium-swift dependency to 3.0.12

## 3.0.9
- Ensure fallback not triggered if presenting a paywall while another already presented

## 3.0.8
- Fix for usage of Flutter fallback view

## 3.0.7
- Remove hard requirement for fallback bundle

## 3.0.6
- Updated helium-swift dependency to 3.0.6

## 3.0.5
- Updated helium-swift dependency to 3.0.5

## 3.0.3
- Updated helium-swift dependency to 3.0.3

## 0.1.3
- Updated helium-swift dependency to 2.3.0

## 0.1.2
- Updated helium-swift dependency to 2.1.0

## 0.1.1
- Updated helium-swift dependency to 2.0.17

## 0.1.0
- Updated helium-swift dependency to 2.0.13
- New getPaywallInfo method available
- Small changes to makePurchase/restorePurchase delegate methods for better error handling & readability

## 0.0.12
- Updated helium-swift dependency to 2.0.11

## 0.0.11
- Updated helium-swift dependency to 2.0.10

## 0.0.10
- Updated helium-swift dependency to 2.0.9

## 0.0.9

- hideUpsell and paywallsLoaded simply return non-optional bools now

## 0.0.8

- New `HeliumFlutter.getUpsellWidget` method to embed a paywall directly in your widget tree
- Bug fixes

## 0.0.7

- Lower minimum-supported Flutter version to 3.24.0 (Dart v3.5.0)

## 0.0.6

- Paywall locked to portrait orientation & other fixes/improvements

## 0.0.5

- Improvements

## 0.0.4

- CocoaPods compatibility added

## 0.0.3

- Updated README installation instructions

## 0.0.2

- Updated license, changelog, and readme

## 0.0.1

- Initial release
