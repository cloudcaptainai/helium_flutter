import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_environment.dart';
import 'package:helium_flutter_example/core/payment_callbacks.dart';

import 'package:helium_flutter_example/presentation/home_page.dart';
import 'package:helium_revenuecat/helium_revenuecat.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // need this since initializing Helium before runApp call
  initializeRevenueCat();
  initializeHelium();
  runApp(const MyApp());
}

// Platform messages are asynchronous, so we initialize in an async method.
Future<void> initializeHelium() async {
  final heliumFlutterPlugin = HeliumFlutter();
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['API_KEY'] ?? '';
  final customUserId = dotenv.env['CUSTOM_USER_ID'];
  // Platform messages may fail, so we use a try/catch PlatformException.
  // We also handle the message potentially returning null.
  try {
    await heliumFlutterPlugin.initialize(
      apiKey: apiKey,
      fallbackPaywall: Text("fallback view here..."),
      customUserId: customUserId,
      callbacks: LogCallbacks(),
      environment: HeliumEnvironment.production);
  } on PlatformException {
    rethrow;
  } catch (e) {
    rethrow;
  }
}

Future<void> initializeRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;
  if (Platform.isIOS) {
    configuration = PurchasesConfiguration('<your-purchase-api>');
    await Purchases.configure(configuration);
  }
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
