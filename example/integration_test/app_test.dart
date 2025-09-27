// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

//Run with this
//flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshot_test.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter_example/main.dart';
import 'package:integration_test/integration_test.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final HeliumFlutter plugin = HeliumFlutter();

  group('End2End test', () {
    setUp(() async {
      await initializeHeliumSwift();
    });
    testWidgets('when initialize called', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await binding.takeScreenshot('start_up');
      await Future.delayed(Duration(seconds: 1));
      //download status
      final downloadStatus = find.byKey(const ValueKey('download_status'));
      await tester.tap(downloadStatus);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('download_status');
      //user id
      final userId = find.byKey(const ValueKey('user_id'));
      await tester.tap(userId);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('user_id');
      //Is upsell hidden
      final upsellHidden = find.byKey(const ValueKey('is_upsell_hidden'));
      await tester.tap(upsellHidden);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('is_upsell_hidden');
      //Is paywall loaded
      final paywallLoaded = find.byKey(const ValueKey('is_paywall_loaded'));
      await tester.tap(paywallLoaded);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('is_paywall_loaded');
      //Present upsell
      final presentUpsell = find.byKey(const ValueKey('present_upsell'));
      await tester.tap(presentUpsell);
      await tester.pumpAndSettle(Duration(seconds: 4));
      await binding.takeScreenshot('present_upsell');
      await plugin.hideUpsell();
      await tester.pumpAndSettle(Duration(seconds: 2));
      //Present view for trigger
      final viewForTrigger = find.byKey(const ValueKey('view_for_trigger'));
      await tester.tap(viewForTrigger);
      await tester.pumpAndSettle(Duration(seconds: 4));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('view_for_trigger');
    });
  });
}

// Platform messages are asynchronous, so we initialize in an async method.
Future<void> initializeHeliumSwift() async {
  final heliumFlutterPlugin = HeliumFlutter();
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['API_KEY'] ?? '';
  final customAPIEndpoint = dotenv.env['CUSTOM_API_END_POINT'] ?? '';
  final customUserId = dotenv.env['CUSTOM_USER_ID'] ?? '';
  // Platform messages may fail, so we use a try/catch PlatformException.
  // We also handle the message potentially returning null.
  try {
    await heliumFlutterPlugin.initialize(
      apiKey: apiKey,
      fallbackPaywall: Text("test fallback"),
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
