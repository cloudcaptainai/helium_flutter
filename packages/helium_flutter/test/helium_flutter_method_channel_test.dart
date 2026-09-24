import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_flutter_method_channel.dart';
import 'package:helium_flutter/helium_flutter.dart';

import 'core/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HeliumFlutterMethodChannel platform = HeliumFlutterMethodChannel();
  const MethodChannel channel = MethodChannel(heliumFlutter);

  late InitializeValue initializeValue;
  late BuildContext context;
  String? lastPresentationId;

  setUp(() async {
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
          lastPresentationId = methodCall.arguments['presentationId'];
          return 'Upsell presented!';
        default:
      }
      return null;
    });
    lastPresentationId = null;
    await platform.resetHelium();
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
    expect(lastPresentationId, startsWith('onboarding:'));
  });

  // Simulates a native -> Dart method call to the handler registered via
  // setMethodCallHandler (i.e. how the native side reports events back).
  Future<ByteData?> sendFromNative(MethodCall call) async {
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      heliumFlutter,
      const StandardMethodCodec().encodeMethodCall(call),
      (ByteData? data) => reply = data,
    );
    return reply;
  }

  void expectHandlerDidNotThrow(ByteData? reply) {
    expect(
      () => const StandardMethodCodec().decodeEnvelope(reply!),
      returnsNormally,
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

    final reply =
        await sendFromNative(const MethodCall(onPaywallEntitledMethodName));
    expectHandlerDidNotThrow(reply);
  });

  testWidgets('onPaywallUnavailable fires on onPaywallUnavailable',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var unavailableCalls = 0;
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallUnavailable: () => unavailableCalls++,
    );

    await sendFromNative(MethodCall(onPaywallUnavailableMethodName, {
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'someError',
      'presentationId': lastPresentationId,
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
    await sendFromNative(MethodCall(onPaywallUnavailableMethodName, {
      'type': 'paywallOpenFailed',
      'paywallUnavailableReason': 'someError',
      'presentationId': lastPresentationId,
    }));
    await tester.pump();
    expect(unavailableCalls, 1);
  });

  const skipArgs = {
    'type': 'paywallSkipped',
    'triggerName': 'onboarding',
    'skipReason': 'targetingHoldout',
  };
  const alreadyEntitledArgs = {
    'type': 'paywallSkipped',
    'triggerName': 'onboarding',
    'skipReason': 'alreadyEntitled',
  };

  testWidgets('onPaywallSkip fires on onPaywallSkip and then clears',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, hasLength(1));
    expect(skips.single.triggerName, 'onboarding');
    expect(skips.single.skipReason, PaywallSkippedReason.targetingHoldout);

    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, hasLength(1));
  });

  testWidgets('already-entitled routes to onPaywallSkip without onEntitled',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(
        const MethodCall(onPaywallEntitledMethodName, alreadyEntitledArgs));
    expect(skips, hasLength(1));
    expect(skips.single.skipReason, PaywallSkippedReason.alreadyEntitled);
  });

  testWidgets('already-entitled routes to onEntitled when provided',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var entitledCalls = 0;
    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => entitledCalls++,
      onPaywallSkip: skips.add,
    );

    await sendFromNative(
        const MethodCall(onPaywallEntitledMethodName, alreadyEntitledArgs));
    expect(entitledCalls, 1);
    expect(skips, isEmpty);
  });

  testWidgets(
      'dedicated already-entitled skip routes to onEntitled when provided',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var entitledCalls = 0;
    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => entitledCalls++,
      onPaywallSkip: skips.add,
    );

    await sendFromNative(
        const MethodCall(onPaywallSkipMethodName, alreadyEntitledArgs));
    expect(entitledCalls, 1);
    expect(skips, isEmpty);
  });

  testWidgets(
      'already-entitled consumed by onEntitled clears pending onPaywallSkip',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var entitledCalls = 0;
    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => entitledCalls++,
      onPaywallSkip: skips.add,
    );

    await sendFromNative(
        const MethodCall(onPaywallEntitledMethodName, alreadyEntitledArgs));
    await sendFromNative(
        const MethodCall(onPaywallSkipMethodName, alreadyEntitledArgs));
    expect(entitledCalls, 1);
    expect(skips, isEmpty);
  });

  testWidgets('onPaywallEntitled with null arguments still calls onEntitled',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    var entitledCalls = 0;
    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => entitledCalls++,
      onPaywallSkip: skips.add,
    );

    await sendFromNative(const MethodCall(onPaywallEntitledMethodName));
    expect(entitledCalls, 1);
    expect(skips, isEmpty);
  });

  testWidgets('a throwing onPaywallSkip callback is contained',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: (_) => throw Exception('boom'),
    );

    final reply = await sendFromNative(
        const MethodCall(onPaywallSkipMethodName, skipArgs));
    expectHandlerDidNotThrow(reply);
  });

  testWidgets('an unrecognized skipReason still invokes onPaywallSkip as unknown',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(const MethodCall(onPaywallSkipMethodName, {
      'type': 'paywallSkipped',
      'triggerName': 'onboarding',
      'skipReason': 'somethingNew',
    }));
    expect(skips, hasLength(1));
    expect(skips.single.triggerName, 'onboarding');
    expect(skips.single.skipReason, PaywallSkippedReason.unknown);
  });

  testWidgets(
      'global paywallSkipped event does not clear pending onPaywallSkip',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(const MethodCall(onPaywallEventMethodName, skipArgs));
    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, hasLength(1));
  });

  testWidgets('onPaywallSkip re-entering presentUpsell keeps the fresh handler',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final secondSkips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: (_) {
        platform.presentUpsell(
          context: context,
          trigger: 'second',
          onPaywallSkip: secondSkips.add,
        );
      },
    );

    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(secondSkips, hasLength(1));
  });

  testWidgets('paywallClose clears pending onPaywallSkip',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(MethodCall(onPaywallEventHandlerMethodName, {
      'type': 'paywallClose',
      'triggerName': 'onboarding',
      'presentationId': lastPresentationId,
    }));
    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, isEmpty);
  });

  testWidgets('paywallOpenFailed clears pending onPaywallSkip',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(MethodCall(onPaywallUnavailableMethodName, {
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'someError',
      'presentationId': lastPresentationId,
    }));
    await tester.pump();
    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, isEmpty);
  });

  testWidgets('a failed presentUpsell bridge call clears pending onPaywallSkip',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == presentUpsellMethodName) {
        throw PlatformException(code: 'x');
      }
      return null;
    });

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, isEmpty);
  });

  testWidgets('resetHelium clears pending onPaywallSkip',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);

    final skips = <PaywallSkippedEvent>[];
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: skips.add,
    );

    await platform.resetHelium();
    await sendFromNative(const MethodCall(onPaywallSkipMethodName, skipArgs));
    expect(skips, isEmpty);
  });

  const previewTrigger = 'helium_preview_trigger';

  Future<void> perCall(
    String type, {
    String trigger = 'onboarding',
    String? presentationId,
    Map<String, dynamic> extra = const {},
  }) =>
      sendFromNative(MethodCall(onPaywallEventHandlerMethodName, {
        'type': type,
        'triggerName': trigger,
        'paywallName': 'test-paywall',
        'presentationId': presentationId ?? lastPresentationId,
        ...extra,
      }));

  Future<void> globalEvent(Map<String, dynamic> args) =>
      sendFromNative(MethodCall(onPaywallEventMethodName, args));

  Future<void> unavailable(String presentationId,
          {String trigger = 'onboarding'}) =>
      sendFromNative(MethodCall(onPaywallUnavailableMethodName, {
        'type': 'paywallOpenFailed',
        'triggerName': trigger,
        'paywallUnavailableReason': 'paywallsNotDownloaded',
        'presentationId': presentationId,
      }));

  PaywallEventHandlers collectInto(List<String> types) =>
      PaywallEventHandlers(onAnyEvent: (event) => types.add(event.type));

  testWidgets('a repeat present rejected as alreadyPresented keeps the on-screen handlers',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];
    final rejectedTypes = <String>[];
    var unavailableCalls = 0;

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
      onPaywallUnavailable: () => unavailableCalls++,
    );
    final id = lastPresentationId!;
    await perCall('paywallOpen');
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(rejectedTypes),
      onPaywallUnavailable: () => unavailableCalls++,
    );
    final rejectedId = lastPresentationId!;
    await globalEvent({
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'alreadyPresented',
    });
    await perCall('purchasePressed', presentationId: id);
    await perCall('purchaseCancelled', presentationId: id);
    await perCall('purchaseRestoreFailed', presentationId: id);
    await perCall('purchasePressed', presentationId: rejectedId);

    expect(types, ['paywallOpen', 'purchasePressed', 'purchaseCancelled', 'purchaseRestoreFailed']);
    expect(rejectedTypes, isEmpty);
    expect(unavailableCalls, 0);
  });

  testWidgets('drops the rejected present when native reports the rejection on its own channel',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];
    final rejectedTypes = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
    );
    final id = lastPresentationId!;
    await perCall('paywallOpen');
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(rejectedTypes),
    );
    final rejectedId = lastPresentationId!;
    await perCall('paywallOpenFailed',
        presentationId: rejectedId,
        extra: {'paywallUnavailableReason': 'alreadyPresented'});
    await globalEvent({
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'alreadyPresented',
    });
    await perCall('purchasePressed', presentationId: id);
    await perCall('purchasePressed', presentationId: rejectedId);

    expect(types, ['paywallOpen', 'purchasePressed']);
    expect(rejectedTypes, ['paywallOpenFailed']);
  });

  testWidgets('keeps the first present when a same-trigger repeat lands before it opens',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final firstTypes = <String>[];
    final rejectedTypes = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(firstTypes),
    );
    final firstId = lastPresentationId!;
    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(rejectedTypes),
    );
    final rejectedId = lastPresentationId!;
    await perCall('paywallOpen', presentationId: firstId);
    await globalEvent({
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding',
      'paywallUnavailableReason': 'alreadyPresented',
    });
    await perCall('purchasePressed', presentationId: firstId);
    await perCall('purchasePressed', presentationId: rejectedId);

    expect(firstTypes, ['paywallOpen', 'purchasePressed']);
    expect(rejectedTypes, isEmpty);
  });

  testWidgets('a second try with no match keeps the on-screen handlers',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
    );
    await perCall('paywallOpen');
    await globalEvent({
      'type': 'paywallOpenFailed',
      'triggerName': 'onboarding_second_try',
      'paywallUnavailableReason': 'secondTryNoMatch',
    });
    await perCall('purchasePressed');

    expect(types, ['paywallOpen', 'purchasePressed']);
  });

  testWidgets('preview paywall events are delivered and the preview lifecycle does not detach handlers',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
    );
    await perCall('paywallOpen');
    await perCall('paywallOpen', trigger: previewTrigger);
    await perCall('purchaseRestoreFailed', trigger: previewTrigger);
    await perCall('paywallClose',
        trigger: previewTrigger, extra: {'isSecondTry': false});
    await globalEvent({
      'type': 'paywallOpenFailed',
      'triggerName': previewTrigger,
      'paywallUnavailableReason': 'paywallsNotDownloaded',
    });
    await globalEvent({
      'type': 'paywallClose',
      'triggerName': previewTrigger,
      'isSecondTry': false,
    });
    await perCall('purchasePressed');

    expect(types, ['paywallOpen', 'paywallOpen', 'purchaseRestoreFailed', 'paywallClose', 'purchasePressed']);
  });

  testWidgets('routes a skip to the present that registered it',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final firstSkips = <PaywallSkippedEvent>[];
    final secondSkips = <PaywallSkippedEvent>[];
    final secondTypes = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallSkip: firstSkips.add,
    );
    final firstId = lastPresentationId!;
    await platform.presentUpsell(
      context: context,
      trigger: 'settings',
      eventHandlers: collectInto(secondTypes),
      onPaywallSkip: secondSkips.add,
    );
    final secondId = lastPresentationId!;
    await sendFromNative(MethodCall(onPaywallSkipMethodName, {
      ...skipArgs,
      'presentationId': firstId,
    }));
    await perCall('paywallOpen', trigger: 'settings', presentationId: secondId);
    await perCall('purchasePressed',
        trigger: 'settings', presentationId: secondId);

    expect(firstSkips, hasLength(1));
    expect(secondSkips, isEmpty);
    expect(secondTypes, ['paywallOpen', 'purchasePressed']);
  });

  testWidgets("routes an already-entitled skip to that present's onEntitled",
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    var firstEntitled = 0;
    var secondEntitled = 0;

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onEntitled: () => firstEntitled++,
    );
    final firstId = lastPresentationId!;
    await platform.presentUpsell(
      context: context,
      trigger: 'settings',
      onEntitled: () => secondEntitled++,
    );
    await sendFromNative(MethodCall(onPaywallEntitledMethodName, {
      ...alreadyEntitledArgs,
      'presentationId': firstId,
    }));

    expect(firstEntitled, 1);
    expect(secondEntitled, 0);
  });

  testWidgets('routes an open failure to the present that failed',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    var firstUnavailable = 0;
    var secondUnavailable = 0;
    final secondTypes = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      onPaywallUnavailable: () => firstUnavailable++,
    );
    final firstId = lastPresentationId!;
    await platform.presentUpsell(
      context: context,
      trigger: 'settings',
      eventHandlers: collectInto(secondTypes),
      onPaywallUnavailable: () => secondUnavailable++,
    );
    final secondId = lastPresentationId!;
    await unavailable(firstId);
    await tester.pump();
    await perCall('paywallOpen', trigger: 'settings', presentationId: secondId);

    expect(firstUnavailable, 1);
    expect(secondUnavailable, 0);
    expect(secondTypes, ['paywallOpen']);
  });

  testWidgets('ends a presentation on its own close but still delivers a later entitled event',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];
    var entitledCalls = 0;

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
      onEntitled: () => entitledCalls++,
    );
    final id = lastPresentationId!;
    await perCall('paywallOpen');
    await perCall('paywallClose', extra: {'isSecondTry': false});
    await perCall('purchasePressed');
    await sendFromNative(MethodCall(onPaywallEntitledMethodName, {
      'type': 'purchaseSucceeded',
      'triggerName': 'onboarding',
      'presentationId': id,
    }));
    await sendFromNative(MethodCall(onPaywallEntitledMethodName, {
      'type': 'purchaseSucceeded',
      'triggerName': 'onboarding',
      'presentationId': id,
    }));

    expect(types, ['paywallOpen', 'paywallClose']);
    expect(entitledCalls, 1);
  });

  testWidgets('ignores close and skipped events on the global channel',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
    );
    await perCall('paywallOpen');
    await globalEvent({
      'type': 'paywallClose',
      'triggerName': 'onboarding',
      'isSecondTry': false,
    });
    await globalEvent(skipArgs);
    await perCall('purchasePressed');

    expect(types, ['paywallOpen', 'purchasePressed']);
  });

  testWidgets('per-call events without a presentation id do not reach presentUpsell handlers',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
    );
    await sendFromNative(const MethodCall(onPaywallEventHandlerMethodName, {
      'type': 'paywallOpen',
      'triggerName': 'onboarding',
      'paywallName': 'test-paywall',
    }));

    expect(types, isEmpty);
  });

  testWidgets('a real open failure still clears the handlers and reports it',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];
    var unavailableCalls = 0;

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
      onPaywallUnavailable: () => unavailableCalls++,
    );
    await perCall('paywallOpen');
    await unavailable(lastPresentationId!);
    await tester.pump();
    await perCall('purchasePressed');

    expect(types, ['paywallOpen']);
    expect(unavailableCalls, 1);
  });

  testWidgets('resetHelium clears every presentation',
      (WidgetTester tester) async {
    await pumpContext(tester);
    await platform.initialize(apiKey: initializeValue.apiKey);
    final types = <String>[];

    await platform.presentUpsell(
      context: context,
      trigger: 'onboarding',
      eventHandlers: collectInto(types),
    );
    await perCall('paywallOpen');
    await platform.resetHelium();
    await perCall('purchasePressed');

    expect(types, ['paywallOpen']);
  });
}
