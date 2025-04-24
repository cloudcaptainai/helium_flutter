import 'dart:developer';

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

  setUp(() {
    initializeValue = InitializeValue(
      apiKey: 'sk-your-api-key',
      callbacks: PaymentCallbacks(),
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
            case getDownloadStatusMethodName:
              return 'Completed';
            case getHeliumUserIdMethodName:
              return 'Test';
            case hideUpsellMethodName:
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
        callbacks: initializeValue.callbacks,
        apiKey: initializeValue.apiKey,
        customUserId: initializeValue.customUserId,
        customAPIEndpoint: initializeValue.customAPIEndpoint,
        customUserTraits: initializeValue.customUserTraits,
      ),
      'Initialization started!',
    );
  });
  test(getDownloadStatusMethodName, () async {
    expect(await platform.getDownloadStatus(), 'Completed');
  });
  test(getHeliumUserIdMethodName, () async {
    expect(await platform.getHeliumUserId(), 'Test');
  });
  test(hideUpsellMethodName, () async {
    expect(await platform.hideUpsell(), true);
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
  test(presentUpsellMethodName, () async {
    expect(
      await platform.presentUpsell(trigger: 'onboarding'),
      'Upsell presented!',
    );
  });
}
