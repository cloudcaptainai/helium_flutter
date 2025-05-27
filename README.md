# helium_flutter

## **Installation**

Add the helium_flutter package to your pubspec.yaml:

```yaml
dependencies:
  helium_flutter: ^0.0.7
```

Then run:

```bash
flutter pub get
```

The minimum version of Flutter supported by this SDK is **3.24.0**.

**Recommended -**  Make sure that Swift Package Manager support is enabled:

```bash
flutter upgrade
flutter config --enable-swift-package-manager
```

See this [Flutter documentation](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers) for more details.

**Note -** You can still use Cocoapods for your dependencies if preferred. If you need to disable Swift Package Manager dependencies after having enabled it, refer to that same [Flutter documentation](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#how-to-turn-off-swift-package-manager).

### iOS Settings

Helium requires a deployment target of iOS 14 or higher. This can be specified by setting it in your `ios/Podfile`with:

```
platform :ios, '14.0'
```

If you still see errors related to minimum iOS version, consider updating to 14.0 or higher [directly in the Xcode project](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#how-to-use-a-swift-package-manager-flutter-plugin-that-requires-a-higher-os-version).

## Configuration

### Set up your HeliumCallbacks

To integrate Helium paywalls, create a class that implements the `HeliumCallbacks` interface. This class is responsible for handling the purchase logic for your paywalls.

```dart
abstract class HeliumCallbacks {
  // [REQUIRED] - Trigger the purchase of a product with the provided product ID.
  // This method should return a HeliumTransactionStatus enum.
  Future<HeliumTransactionStatus> makePurchase(String productId);

  // [OPTIONAL] - Restore any existing subscriptions.
  // This method should return a boolean indicating whether the restore was successful.
  Future<bool> restorePurchases(bool status);

  // [OPTIONAL] - Custom analytics/error logging for paywall/helium related events.
  // By default, events are logged to your analytics service, but you can override 
  // this method to add additional custom logging/handling.
  Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent);
}
```

The `HeliumTransactionStatus` enum defines the possible states of a paywall transaction:

```dart
enum HeliumTransactionStatus { 
  purchased, 
  failed, 
  cancelled, 
  restored, 
  pending 
}
```

### Example Callbacks Implementation:

#### Basic Implementation

Here's a basic implementation of the `HeliumCallbacks` interface:

```dart
import 'package:helium_flutter/helium_flutter.dart';
import 'dart:developer';

class PaymentCallbacks implements HeliumCallbacks {
  @override
  Future<HeliumTransactionStatus> makePurchase(String productId) async {
    log('makePurchase: $productId');
    // Implement your purchase logic here
    return HeliumTransactionStatus.purchased;
  }

  @override
  Future<bool> restorePurchases(bool status) async {
    log('restorePurchases: $status');
    // Implement your restore logic here
    return status;
  }

  @override
  Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent) async {
    log('onPaywallEvent: $heliumPaywallEvent');
    // Handle paywall events here
  }
}
```

#### RevenueCat Implementation

```dart
import 'package:helium_flutter/helium_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer';

class RevenueCatCallbacks implements HeliumCallbacks {
  @override
  Future<HeliumTransactionStatus> makePurchase(String productId) async {
    try {
      log('RevenueCat making purchase: $productId');
      final offerings = await Purchases.getOfferings();
      
      Package? packageToPurchase;
      
      // Find the package in current offering
      if (offerings.current != null) {
        for (var package in offerings.current!.availablePackages) {
          if (package.storeProduct.identifier == productId) {
            packageToPurchase = package;
            break;
          }
        }
      }
      
      // If not found in current, search all offerings
      if (packageToPurchase == null) {
        for (var offering in offerings.all.values) {
          for (var package in offering.availablePackages) {
            if (package.storeProduct.identifier == productId) {
              packageToPurchase = package;
              break;
            }
          }
          if (packageToPurchase != null) break;
        }
      }
      
      if (packageToPurchase == null) {
        log('Product not found in any offering: $productId');
        return HeliumTransactionStatus.failed;
      }
      
      final customerInfo = await Purchases.purchasePackage(packageToPurchase);
      
      // Check if the purchase was successful by looking at entitlements
      if (customerInfo.entitlements.active.isNotEmpty) {
        return HeliumTransactionStatus.purchased;
      } else {
        return HeliumTransactionStatus.failed;
      }
    } catch (e) {
      log('RevenueCat purchase error: $e');
      if (e is PurchasesErrorCode) {
        if (e == PurchasesErrorCode.purchaseCancelledError) {
          return HeliumTransactionStatus.cancelled;
        } else if (e == PurchasesErrorCode.paymentPendingError) {
          return HeliumTransactionStatus.pending;
        }
      }
      return HeliumTransactionStatus.failed;
    }
  }

  @override
  Future<bool> restorePurchases(bool status) async {
    try {
      log('RevenueCat restoring purchases');
      final restoredInfo = await Purchases.restorePurchases();
      return restoredInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      log('RevenueCat restore error: $e');
      return false;
    }
  }

  @override
  Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent) async {
    log('RevenueCat paywall event: $heliumPaywallEvent');
    // Handle specific events as needed
    final eventType = heliumPaywallEvent['type'];
    
    if (eventType == 'subscriptionSucceeded') {
      // Handle successful subscription
      final productId = heliumPaywallEvent['productKey'];
      log('Subscription succeeded for product: $productId');
      
      // Add your custom analytics tracking here
    }
  }
}
```

### Initialize Helium and Download Paywall Configs

In your app's initialization code (typically in `main.dart` or your root widget), add the following to download paywall configurations:

```dart
import 'package:helium_flutter/helium_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create your callbacks implementation
  PaymentCallbacks paymentCallbacks = PaymentCallbacks();
  
  // Initialize Helium
  final heliumFlutter = HeliumFlutter();
  heliumFlutter.initialize(
    // You'll get this from Helium founders during setup!
    apiKey: "<your-helium-api-key>",
    
    // The callbacks implementation you created earlier
    callbacks: paymentCallbacks,

    // Defines a fallback paywall to show in case the user's device is not connected to the internet.
    fallbackPaywall: Text("fallback display")
    
    // If set, a custom API endpoint (usually provided by Helium)
    customAPIEndpoint: "https://api-v2.tryhelium.com/on-launch",
    
    // If set, a custom user ID to use instead of Helium's
    customUserId: "your-custom-user-id", // Optional
    
    // Custom user traits for targeting and personalization
    customUserTraits: {
      "exampleUserTrait": "test_value",
      "subscriptionStatus": "active",
      "userIntent": "upgrade",
      "numericalValue": 3.0,
    }, // Optional
  );
  
  runApp(const MyApp());
}
```

#### Passing Custom User Traits

Custom user traits can be any key-value pairs where the value is a serializable type (String, num, bool, etc.). These traits can be used for targeting, personalization, and dynamic content in your paywalls.

#### Passing in a Custom User ID

By default, Helium generates a UUID per app session to identify users. You can override this with your own custom user ID (e.g., from a 3rd party analytics service) by passing it in the `initialize` method or by explicitly calling `overrideUserId`:

```dart
// Set a custom user ID
await heliumFlutter.overrideUserId(
  newUserId: "your-custom-user-id", 
  traits: {
    "exampleTrait": "value",
    "userType": "premium"
  }
);
```

#### Checking Download Status

After initialization, you can check the status of the paywall configuration download:

```dart
String downloadStatus = await heliumFlutter.getDownloadStatus() ?? 'Unknown';
```

The download status will be one of the following:

- `"notDownloadedYet"`: The download has not been initiated or is still in progress.
- `"downloadSuccess"`: The download was successful.
- `"downloadFailure"`: The download failed.

You can use this to handle different states in your app.

#### Checking if Paywalls are Loaded

You can also check if paywalls have been loaded successfully:

```dart
bool paywallsLoaded = await heliumFlutter.paywallsLoaded() ?? false;
```

## Presenting Paywalls

There are several ways to present Helium paywalls in your Flutter app:

### Via Direct Method Call

You can present a paywall programmatically using the `presentUpsell` method:

```dart
ElevatedButton(
  onPressed: () {
    final heliumFlutter = HeliumFlutter();
    heliumFlutter.presentUpsell(context: context, trigger: 'insert-trigger-here');
  },
  child: Text('Show Premium Features'),
),
```

The `trigger` parameter is a unique identifier for the paywall trigger point in your app. Helium uses this to track and optimize the paywall for each trigger point.

### Via Widget Integration

You can also use the `HeliumFlutter.getUpsellWidget` method to embed a paywall directly in your widget tree:

```dart
class ExamplePageWithEmbeddedPaywall extends StatelessWidget {
  const ExamplePageWithEmbeddedPaywall({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeliumFlutter().getUpsellWidget(trigger: "insert-trigger-here"),
    );
  }
}
```

### Hiding Paywalls

To programmatically hide a paywall:

```dart
bool hideResult = await heliumFlutter.hideUpsell() ?? false;
```

### Handling Custom Dismissal Actions

You can implement custom dismissal logic by handling paywall events in your `HeliumCallbacks` implementation:

```dart
@override
Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent) async {
  final eventType = heliumPaywallEvent['type'];
  
  if (eventType == 'ctaPressed') {
    final ctaName = heliumPaywallEvent['ctaName'];
    final triggerName = heliumPaywallEvent['triggerName'];
    
    if (ctaName == 'dismiss') {
      // Handle custom dismissal logic here
      // For example, navigate back or show a different screen
    }
  }
}
```

## Getting User ID

To retrieve the Helium user ID:

```dart
String userId = await heliumFlutter.getHeliumUserId() ?? 'Unknown';
```

## Testing

Documentation for testing will be provided separately. After integration, please message us directly to get set up with a test app + in-app test support.
