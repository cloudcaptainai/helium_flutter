import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter_example/core/payment_callbacks.dart';

import 'package:helium_flutter_example/presentation/home_page.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeHeliumSwift();
  initializeRevenueCat();
  runApp(const MyApp());
}

// Platform messages are asynchronous, so we initialize in an async method.
Future<void> initializeHeliumSwift() async {
  final heliumFlutterPlugin = HeliumFlutter();
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['API_KEY'] ?? '';
  final customAPIEndpoint = dotenv.env['CUSTOM_API_END_POINT'] ?? '';
  final customUserId = dotenv.env['CUSTOM_USER_ID'] ?? '';
  PaymentCallbacks paymentCallbacks = PaymentCallbacks();
  // Platform messages may fail, so we use a try/catch PlatformException.
  // We also handle the message potentially returning null.
  try {
    await heliumFlutterPlugin.initialize(
      apiKey: apiKey,
      callbacks: paymentCallbacks,
      customAPIEndpoint: customAPIEndpoint,
      customUserId: customUserId,
      customUserTraits: {
        'exampleUserTrait': 'test_value',
        'somethingElse': 'somethingElse',
        'somethingElse2': 'somethingElse2',
        'vibes': 3.0,
      },
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
