# helium_revenuecat

The `helium_revenuecat` package provides a seamless integration between the **Helium Paywall SDK** and **RevenueCat**.

It implements the `HeliumPurchaseDelegate` interface, allowing Helium to delegate purchase flows and entitlement checks directly to RevenueCat's `purchases_flutter` plugin. This ensures that your RevenueCat configuration, products, and entitlements remain the single source of truth while leveraging Helium's powerful paywall optimization and experimentation features.

## Usage

To use this package, you must initialize RevenueCat *before* initializing Helium. Pass an instance of `RevenueCatPurchaseDelegate` to the Helium initialization method.

```dart
import 'package:flutter/material.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_revenuecat/helium_revenuecat.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize RevenueCat
  // Make sure to configure RevenueCat with your API key as usual.
  await Purchases.configure(PurchasesConfiguration("YOUR_REVENUECAT_API_KEY"));

  // 2. Initialize Helium
  // Create an instance of HeliumFlutter and pass the RevenueCatPurchaseDelegate.
  final helium = HeliumFlutter();
  
  await helium.initialize(
    apiKey: "YOUR_HELIUM_API_KEY",
    purchaseDelegate: RevenueCatPurchaseDelegate(),
    // Optional: Pass the RevenueCat App User ID to Helium for server-side events
    revenueCatAppUserId: await Purchases.appUserID, 
  );

  runApp(const MyApp());
}
```

For full documentation on the Helium SDK, visit [docs.tryhelium.com](https://docs.tryhelium.com/sdk/quickstart-flutter).
