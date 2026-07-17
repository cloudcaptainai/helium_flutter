import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_flutter_method_channel.dart';

import 'core/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HeliumFlutterMethodChannel platform = HeliumFlutterMethodChannel();
  const MethodChannel channel = MethodChannel(heliumFlutter);

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case initializeMethodName:
              log(methodCall.arguments.toString());
              return 'Initialization started!';
            case getHeliumUserIdMethodName:
              return 'Test';
            case hideUpsellMethodName:
              return true;
            case hideAllUpsellsMethodName:
              return true;
            case overrideUserIdMethodName:
              return methodCall.arguments['newUserId'];
            case paywallsLoadedMethodName:
              return true;
            case presentUpsellMethodName:
              return 'Upsell presented!';
            default:
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(initializeMethodName, () async {
    expect(
      await platform.initialize(
        fallbackPaywall: Text('Test'),
        apiKey: initializeValue.apiKey,
        customUserId: initializeValue.customUserId,
        customAPIEndpoint: initializeValue.customAPIEndpoint,
        customUserTraits: initializeValue.customUserTraits,
        androidConsumableProductIds: {'consumable_1'},
      ),
      'Initialization started!',
    );
  });
  test(getHeliumUserIdMethodName, () async {
    expect(await platform.getHeliumUserId(), 'Test');
  });
  test(hideUpsellMethodName, () async {
    expect(await platform.hideUpsell(), true);
  });
  test(hideAllUpsellsMethodName, () async {
    expect(await platform.hideAllUpsells(), true);
  });
  test(overrideUserIdMethodName, () async {
    expect(
      await platform.overrideUserId(
        newUserId: 'new_user_id',
        traits: initializeValue.customUserTraits,
      ),
      'new_user_id',
    );
  });
  test(paywallsLoadedMethodName, () async {
    expect(await platform.paywallsLoaded(), true);
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
      await platform.presentUpsell(context: context, trigger: 'onboarding'),
      'Upsell presented!',
    );
  });

  // Simulates a native -> Dart method call to the handler registered via
  // setMethodCallHandler (i.e. how the native side reports events back).
  Future<void> sendFromNative(MethodCall call) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      heliumFlutter,
      const StandardMethodCodec().encodeMethodCall(call),
      (ByteData? _) {},
    );
  }

  Future<void> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext ctx) {
            context = ctx;
            return const Scaffold(body: Text('Test'));
          },
        ),
      ),
    );
  }

  testWidgets('onEntitled fires on onPaywallEntitled and then clears',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var entitledCalls = 0;
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => entitledCalls++,
    );

    await sendFromNative(const MethodCall(onPaywallEntitledMethodName));
    expect(entitledCalls, 1);

    // Fires once, then clears — a second native call is a no-op.
    await sendFromNative(const MethodCall(onPaywallEntitledMethodName));
    expect(entitledCalls, 1);
  });

  testWidgets('a throwing onEntitled callback is contained',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => throw Exception('boom'),
    );

    // Reaching the assertion means the exception did not propagate out of the
    // method-channel handler.
    await sendFromNative(const MethodCall(onPaywallEntitledMethodName));
    expect(true, isTrue);
  });

  testWidgets('onPaywallUnavailable fires on paywallOpenFailed',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var unavailableCalls = 0;
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallUnavailable: () => unavailableCalls++,
    );

    await sendFromNative(const MethodCall(onPaywallEventMethodName, {
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'someError',
    }));
    await tester.pump(); // flush the post-frame fallback-sheet dispatch (no-op)
    expect(unavailableCalls, 1);
  });

  testWidgets('onPaywallUnavailable is skipped for alreadyPresented',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var unavailableCalls = 0;
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallUnavailable: () => unavailableCalls++,
    );

    await sendFromNative(const MethodCall(onPaywallEventMethodName, {
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'alreadyPresented',
    }));
    await tester.pump();
    expect(unavailableCalls, 0);
  });

  testWidgets('onPaywallUnavailable fires even when triggerName is absent',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var unavailableCalls = 0;
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallUnavailable: () => unavailableCalls++,
    );

    // Missing triggerName gates only the Flutter fallback view, not the callback.
    await sendFromNative(const MethodCall(onPaywallEventMethodName, {
      'type': 'paywallOpenFailed',
      'paywallUnavailableReason': 'someError',
    }));
    await tester.pump();
    expect(unavailableCalls, 1);
  });
}
