import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_environment.dart';
import 'package:helium_stripe/helium_stripe.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Tracks calls made to the mock platform so tests can verify behavior.
class MockHeliumFlutterPlatform
    with MockPlatformInterfaceMixin
    implements HeliumFlutterPlatform {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> callArgs = {};
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  void reset() {
    calls.clear();
    callArgs.clear();
    _isInitialized = false;
  }

  @override
  Future<String?> setupCore({
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
  }) async {
    calls.add('setupCore');
    callArgs['setupCore'] = {
      'apiKey': apiKey,
      'customUserId': customUserId,
    };
    _isInitialized = true;
    return 'Core setup complete!';
  }

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
  }) async {
    calls.add('initialize');
    callArgs['initialize'] = {
      'apiKey': apiKey,
      'customUserId': customUserId,
    };
    return 'Initialization started!';
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    Map<String, dynamic>? traits,
  }) async {
    calls.add('overrideUserId');
    callArgs['overrideUserId'] = {'newUserId': newUserId};
    return newUserId;
  }

  @override
  Future<String?> getHeliumUserId() async => 'user_id';
  @override
  Future<bool> hideUpsell() async => true;
  @override
  Future<bool> hideAllUpsells() async => true;
  @override
  Future<bool> paywallsLoaded() async => true;
  @override
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    bool? dontShowIfAlreadyEntitled,
  }) async =>
      'Upsell presented!';
  @override
  Future<PaywallInfo?> getPaywallInfo(String trigger) async => null;
  @override
  Future<bool> handleDeepLink(String uri) async => false;
  @override
  Widget getUpsellWidget({
    required String trigger,
    PaywallEventHandlers? eventHandlers,
  }) =>
      const Text('upsell widget');
  @override
  Future<bool> hasAnyActiveSubscription() async => false;
  @override
  Future<bool> hasAnyEntitlement() async => false;
  @override
  Future<bool?> hasEntitlementForPaywall(String trigger) async => null;
  @override
  Future<ExperimentInfo?> getExperimentInfoForTrigger(String trigger) async =>
      null;
  @override
  void disableRestoreFailedDialog() {}
  @override
  void setCustomRestoreFailedStrings({
    String? customTitle,
    String? customMessage,
    String? customCloseButtonText,
  }) {}
  @override
  Future<void> resetHelium({
    bool clearUserTraits = true,
    bool clearExperimentAllocations = false,
  }) async {}
  @override
  void setLightDarkModeOverride(HeliumLightDarkMode mode) {}
  @override
  void setRevenueCatAppUserId(String rcAppUserId) {}
  @override
  void setAndroidConsumableProductIds(Set<String> productIds) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHeliumFlutterPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockHeliumFlutterPlatform();
    HeliumFlutterPlatform.instance = mockPlatform;
  });

  tearDown(() {
    mockPlatform.reset();
    HeliumStripe.isIOSOverride = null;
  });

  group('initializeWithStripe (non-iOS)', () {
    test('falls back to standard initialize', () async {
      await HeliumStripe.initializeWithStripe(
        apiKey: 'test-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
        customUserId: 'user-123',
      );

      expect(mockPlatform.calls, ['initialize']);
      expect(mockPlatform.calls, isNot(contains('setupCore')));
    });

    test('passes parameters through to initialize', () async {
      await HeliumStripe.initializeWithStripe(
        apiKey: 'test-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
        customUserId: 'user-123',
      );

      final args = mockPlatform.callArgs['initialize']!;
      expect(args['apiKey'], 'test-api-key');
      expect(args['customUserId'], 'user-123');
    });

    test('does not call initializeStripe on the native channel', () async {
      // On non-iOS, no MethodChannel call to helium_stripe should be made.
      // If it were, it would throw since there's no mock handler — the fact
      // that this completes without error proves the channel is not called.
      await HeliumStripe.initializeWithStripe(
        apiKey: 'test-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
      );
    });
  });

  group('initializeWithStripe (iOS)', () {
    const MethodChannel stripeChannel = MethodChannel('helium_stripe');
    late List<MethodCall> channelCalls;

    setUp(() {
      HeliumStripe.isIOSOverride = true;
      channelCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stripeChannel,
              (MethodCall methodCall) async {
        channelCalls.add(methodCall);
        switch (methodCall.method) {
          case 'initializeStripe':
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stripeChannel, null);
    });

    test('calls setupCore before initializeStripe', () async {
      await HeliumStripe.initializeWithStripe(
        apiKey: 'test-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
      );

      // setupCore should be called (not initialize)
      expect(mockPlatform.calls, ['setupCore']);
      expect(mockPlatform.calls, isNot(contains('initialize')));

      // Then initializeStripe should be called on the native channel
      expect(channelCalls, hasLength(1));
      expect(channelCalls.first.method, 'initializeStripe');
    });

    test('sends correct payload keys to initializeStripe', () async {
      await HeliumStripe.initializeWithStripe(
        apiKey: 'my-api-key',
        stripePublishableKey: 'pk_live_abc',
        merchantIdentifier: 'merchant.com.app',
        merchantName: 'My App',
        managementURL: 'https://app.com/manage',
        countryCode: 'GB',
        currencyCode: 'GBP',
      );

      final args =
          channelCalls.first.arguments as Map<Object?, Object?>;
      expect(args['apiKey'], 'my-api-key');
      expect(args['stripePublishableKey'], 'pk_live_abc');
      expect(args['merchantIdentifier'], 'merchant.com.app');
      expect(args['merchantName'], 'My App');
      expect(args['managementURL'], 'https://app.com/manage');
      expect(args['countryCode'], 'GB');
      expect(args['currencyCode'], 'GBP');
    });

    test('uses default countryCode and currencyCode', () async {
      await HeliumStripe.initializeWithStripe(
        apiKey: 'test-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
      );

      final args =
          channelCalls.first.arguments as Map<Object?, Object?>;
      expect(args['countryCode'], 'US');
      expect(args['currencyCode'], 'USD');
    });

    test('skips initializeStripe when already initialized', () async {
      mockPlatform._isInitialized = true;

      await HeliumStripe.initializeWithStripe(
        apiKey: 'test-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
      );

      // Neither setupCore nor initializeStripe should be called
      expect(mockPlatform.calls, isEmpty);
      expect(channelCalls, isEmpty);
    });

    test('passes parameters through to setupCore', () async {
      await HeliumStripe.initializeWithStripe(
        apiKey: 'stripe-api-key',
        stripePublishableKey: 'pk_test_123',
        merchantIdentifier: 'merchant.com.test',
        merchantName: 'Test Merchant',
        managementURL: 'https://example.com/manage',
        customUserId: 'stripe-user',
      );

      final args = mockPlatform.callArgs['setupCore']!;
      expect(args['apiKey'], 'stripe-api-key');
      expect(args['customUserId'], 'stripe-user');
    });
  });

  group('setUserIdAndSyncStripeIfNeeded (non-iOS)', () {
    test('falls back to overrideUserId', () {
      HeliumStripe.setUserIdAndSyncStripeIfNeeded('user-456');

      expect(mockPlatform.calls, ['overrideUserId']);
      expect(
          mockPlatform.callArgs['overrideUserId']!['newUserId'], 'user-456');
    });
  });

  group('resetStripeEntitlements (non-iOS)', () {
    test('is a no-op and does not throw', () {
      HeliumStripe.resetStripeEntitlements();
      HeliumStripe.resetStripeEntitlements(clearUserId: true);

      expect(mockPlatform.calls, isEmpty);
    });
  });

  group('createStripePortalSession (non-iOS)', () {
    test('returns null', () async {
      final result =
          await HeliumStripe.createStripePortalSession('https://return.url');

      expect(result, isNull);
      expect(mockPlatform.calls, isEmpty);
    });
  });

  group('hasActiveStripeEntitlement (non-iOS)', () {
    test('returns false', () async {
      final result = await HeliumStripe.hasActiveStripeEntitlement();

      expect(result, isFalse);
      expect(mockPlatform.calls, isEmpty);
    });
  });
}
