import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:helium_flutter_example/core/payment_callbacks.dart';
import 'package:helium_stripe/helium_stripe.dart';

import 'package:helium_flutter_example/presentation/home_page.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // need this since initializing Helium before runApp call
  initializeRevenueCat();
  initializeHelium();
  runApp(const MyApp());
}

// Platform messages are asynchronous, so we initialize in an async method.
Future<void> initializeHelium() async {
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['API_KEY'] ?? '';
  final stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  final merchantIdentifier = dotenv.env['STRIPE_MERCHANT_IDENTIFIER'] ?? '';
  final merchantName = dotenv.env['STRIPE_MERCHANT_NAME'] ?? '';
  final managementURL = dotenv.env['STRIPE_MANAGEMENT_URL'] ?? '';

  try {
    await HeliumStripe.initializeWithStripe(
      apiKey: apiKey,
      stripePublishableKey: stripePublishableKey,
      merchantIdentifier: merchantIdentifier,
      merchantName: merchantName,
      managementURL: managementURL,
      callbacks: LogCallbacks(),
    );
  } on PlatformException {
    rethrow;
  } catch (e) {
    rethrow;
  }
}

Future<void> initializeRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;
  configuration = PurchasesConfiguration('<your-purchase-api>');
  await Purchases.configure(configuration);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
