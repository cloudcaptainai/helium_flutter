import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_flutter_method_channel.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_environment.dart';
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
    HeliumEnvironment? environment,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
    Set<String>? androidConsumableProductIds,
  }) {
    return Future.value('Initialization started!');
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
  Future<bool> hideAllUpsells() {
    return Future.value(true);
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    Map<String, dynamic>? traits,
  }) {
    return Future.value(newUserId);
  }

  @override
  Future<bool> paywallsLoaded() {
    return Future.value(true);
  }

  @override
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    bool? dontShowIfAlreadyEntitled,
  }) {
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
  Widget getUpsellWidget({
    required String trigger,
    PaywallEventHandlers? eventHandlers,
  }) {
    return Text("upsell widget");
  }

  @override
  Future<bool> hasAnyActiveSubscription() {
    return Future.value(true);
  }

  @override
  Future<bool> hasAnyEntitlement() {
    return Future.value(true);
  }

  @override
  Future<bool?> hasEntitlementForPaywall(String trigger) {
    return Future.value(false);
  }

  @override
  Future<ExperimentInfo?> getExperimentInfoForTrigger(String trigger) {
    return Future.value(null);
  }

  @override
  void disableRestoreFailedDialog() {}

  @override
  void setCustomRestoreFailedStrings({
    String? customTitle,
    String? customMessage,
    String? customCloseButtonText,
  }) {}

  @override
  Future<void> resetHelium() async {}

  @override
  void setLightDarkModeOverride(HeliumLightDarkMode mode) {}

  @override
  void setRevenueCatAppUserId(String rcAppUserId) {}

  @override
  void setAndroidConsumableProductIds(Set<String> productIds) {}
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
  test(getHeliumUserIdMethodName, () async {
    expect(await heliumFlutterPlugin.getHeliumUserId(), 'user_id');
  });
  test(hideUpsellMethodName, () async {
    expect(await heliumFlutterPlugin.hideUpsell(), true);
  });
  test(hideAllUpsellsMethodName, () async {
    expect(await heliumFlutterPlugin.hideAllUpsells(), true);
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
      await heliumFlutterPlugin.presentUpsell(
          context: context, trigger: 'onboarding'),
      'Upsell presented!',
    );
  });
  test(hasAnyActiveSubscriptionMethodName, () async {
    expect(await heliumFlutterPlugin.hasAnyActiveSubscription(), true);
  });
  test(hasAnyEntitlementMethodName, () async {
    expect(await heliumFlutterPlugin.hasAnyEntitlement(), true);
  });
  test(hasEntitlementForPaywallMethodName, () async {
    expect(await heliumFlutterPlugin.hasEntitlementForPaywall('onboarding'),
        false);
  });
  test(setLightDarkModeOverrideMethodName, () {
    // Test that it doesn't throw
    heliumFlutterPlugin.setLightDarkModeOverride(HeliumLightDarkMode.light);
    heliumFlutterPlugin.setLightDarkModeOverride(HeliumLightDarkMode.dark);
    heliumFlutterPlugin.setLightDarkModeOverride(HeliumLightDarkMode.system);
  });
  test(setRevenueCatAppUserIdMethodName, () {
    // Test that it doesn't throw
    heliumFlutterPlugin.setRevenueCatAppUserId('rc_app_user_id_123');
  });
  test(resetHeliumMethodName, () async {
    // Test that resetHelium completes without throwing
    await heliumFlutterPlugin.resetHelium();
  });
  test(setAndroidConsumableProductIdsMethodName, () {
    // Test that it doesn't throw
    heliumFlutterPlugin.setAndroidConsumableProductIds({'product_1', 'product_2'});
  });
}
