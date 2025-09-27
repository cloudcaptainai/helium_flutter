import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_flutter_method_channel.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'core/const.dart';

class MockHeliumFlutterPlatform
    with MockPlatformInterfaceMixin
    implements HeliumFlutterPlatform {
  @override
  Future<String?> initialize({
    required String apiKey,
    HeliumCallbacks? callbacks,
    HeliumPurchaseDelegate? purchaseDelegate,
    Widget? fallbackPaywall,
    String? customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
    String? revenueCatAppUserId,
    String? fallbackBundleAssetPath,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
  }) {
    return Future.value('Initialization started!');
  }

  @override
  Future<String?> getDownloadStatus() {
    return Future.value('Completed');
  }

  @override
  Future<String?> getHeliumUserId() {
    return Future.value('user_id');
  }

  @override
  Future<bool> hideUpsell() {
    return Future.value(true);
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) {
    return Future.value(newUserId);
  }

  @override
  Future<bool> paywallsLoaded() {
    return Future.value(true);
  }

  @override
  Future<String?> presentUpsell({required BuildContext context, required String trigger, PaywallEventHandlers? eventHandlers, Map<String, dynamic>? customPaywallTraits}) {
    return Future.value('Upsell presented!');
  }

  @override
  Future<PaywallInfo?> getPaywallInfo(String trigger) {
    return Future.value(PaywallInfo(
      paywallTemplateName: 'template',
      shouldShow: true,
    ));
  }

  @override
  Future<bool> handleDeepLink(String uri) {
    return Future.value(false);
  }

  @override
  Widget getUpsellWidget({required String trigger}) {
    return Text("upsell widget");
  }

}

void main() {
  final HeliumFlutterPlatform initialPlatform = HeliumFlutterPlatform.instance;
  HeliumFlutter heliumFlutterPlugin = HeliumFlutter();
  MockHeliumFlutterPlatform fakePlatform = MockHeliumFlutterPlatform();
  HeliumFlutterPlatform.instance = fakePlatform;
  late InitializeValue initializeValue;
  late BuildContext context;

  setUp(() {
    initializeValue = InitializeValue(
      apiKey: 'sk-your-api-key',
      customAPIEndpoint: 'https://example.com',
      customUserId: 'customUserId',
      customUserTraits: {
        'exampleUserTrait': 'test_value',
        'somethingElse': 'somethingElse',
        'somethingElse2': 'somethingElse2',
        'vibes': 3.0,
      },
    );
  });

  test('$HeliumFlutterMethodChannel is the default instance', () {
    expect(initialPlatform, isInstanceOf<HeliumFlutterMethodChannel>());
  });

  test(initializeMethodName, () async {
    expect(
      await heliumFlutterPlugin.initialize(
        fallbackPaywall: Text("Test"),
        apiKey: initializeValue.apiKey,
        customUserId: initializeValue.customUserId,
        customAPIEndpoint: initializeValue.customAPIEndpoint,
        customUserTraits: initializeValue.customUserTraits,
      ),
      'Initialization started!',
    );
  });
  test(getDownloadStatusMethodName, () async {
    expect(await heliumFlutterPlugin.getDownloadStatus(), 'Completed');
  });
  test(getHeliumUserIdMethodName, () async {
    expect(await heliumFlutterPlugin.getHeliumUserId(), 'user_id');
  });
  test(hideUpsellMethodName, () async {
    expect(await heliumFlutterPlugin.hideUpsell(), true);
  });
  test(overrideUserIdMethodName, () async {
    expect(
      await heliumFlutterPlugin.overrideUserId(
        newUserId: 'new_user_id',
        traits: initializeValue.customUserTraits,
      ),
      'new_user_id',
    );
  });
  test(paywallsLoadedMethodName, () async {
    expect(await heliumFlutterPlugin.paywallsLoaded(), true);
  });
  testWidgets(presentUpsellMethodName, (WidgetTester tester) async {
    // Build a minimal widget to provide context
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext ctx) {
            // Save the context for use in the test
            context = ctx;
            return const Scaffold(body: Text('Test'));
          },
        ),
      ),
    );

    expect(
      await heliumFlutterPlugin.presentUpsell(context: context, trigger: 'onboarding'),
      'Upsell presented!',
    );
  });
}
