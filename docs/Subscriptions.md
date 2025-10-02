RevenueCat Integration — Sonora

Overview
- Uses `RevenueCatService` implementing the existing `StoreKitServiceProtocol`.
- DI is configured to use RevenueCat only (no StoreKit fallback).
- Existing UI (`Features/Settings/UI/PaywallView.swift`) and quota gating continue to work unchanged via `DIContainer.shared.storeKitService()`.

Setup Steps
- Add SPM dependency: `https://github.com/RevenueCat/purchases-ios` (latest stable)
  - Target: `Sonora`
  - Product: `RevenueCat`
- No further app code changes are required — DI always uses `RevenueCatService`.

Configuration
- API key (iOS): `appl_NuJfLSURCFnBBqcYSlHIwfYreue`
- Entitlement: default assumed `pro`
  - Override with env var `RC_ENTITLEMENT_ID` if different.
- Product mapping (Offerings → StoreKit IDs):
  - `$rc_monthly` → `sonora.pro.monthly`
  - `$rc_annual` → `sonora.pro.annual`

Files
- `Sonora/Core/Payments/RevenueCatService.swift`
  - Configures `Purchases` and listens for updates (delegate).
  - Maps purchases/restores to `isPro` using the `pro` entitlement by default.
- `Sonora/Core/DI/DIContainer.swift`
  - Registers `StoreKitServiceProtocol` to `RevenueCatService` when `RevenueCat` is available; otherwise uses `StoreKitService`.

Behavior
- Purchase flow: `purchase(productId:)` resolves the package from Offerings using product ID and standard RC package ids (`$rc_monthly`, `$rc_annual`).
- Restore flow: `restorePurchases()` uses `Purchases.restorePurchases`.
- Entitlements: `isPro` = active `pro` entitlement (or any active entitlement as fallback).
- Caching: mirrors previous behavior using `storekit.isPro.cached` keys for quick state reads.

Testing
- Build and run to simulator; UI still calls `storeKitService()`.
- Add RevenueCat SPM then build again; DI will route subscriptions to RevenueCat.
- Sandbox: use RevenueCat dashboard + App Store sandbox testers; validate purchase and restore.

Notes
- If your entitlement is not named `pro`, set `RC_ENTITLEMENT_ID` in the scheme’s environment or adjust the initializer in `RevenueCatService`.
- Pricing copy in `PaywallView` is static; we can switch to dynamic prices from Offerings upon request.
