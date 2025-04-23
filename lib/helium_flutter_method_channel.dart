import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';

import 'helium_flutter_platform_interface.dart';

/// An implementation of [HeliumFlutterPlatform] that uses method channels.
class MethodChannelHeliumFlutter extends HeliumFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  MethodChannel methodChannel = const MethodChannel('helium_flutter');

  @override
  Future<String?> initialize({
    required HeliumCallbacks callbacks,
    required String apiKey,
    required String customUserId,
    required String customAPIEndpoint,
    required Map<String, dynamic> customUserTraits,
  }) async {
    _setMethodCallHandlers(callbacks);
    final result = await methodChannel.invokeMethod<String?>('initialize', {
      'apiKey': apiKey,
      'customUserId': customUserId,
      'customAPIEndpoint': customAPIEndpoint,
      'customUserTraits': customUserTraits,
    });
    return result;
  }

  void _setMethodCallHandlers(HeliumCallbacks callbacks) {
    methodChannel.setMethodCallHandler((handler) async {
      if (handler.method == 'makePurchase') {
        String id = handler.arguments as String? ?? '';
        final status = await callbacks.makePurchase(id);
        return status.name;
      } else if (handler.method == 'restorePurchases') {
        bool status = handler.arguments as bool? ?? false;
        callbacks.restorePurchases(status);
      } else if (handler.method == 'onPaywallEvent') {
        String eventString = handler.arguments as String? ?? '';
        Map<String, dynamic> event = jsonDecode(eventString);
        callbacks.onPaywallEvent(event);
      } else {
        log('Unknown method from MethodChannel: ${handler.method}');
      }
    });
  }

  @override
  Future<String?> getDownloadStatus() async {
    final result = await methodChannel.invokeMethod<String?>(
      'getDownloadStatus',
    );
    return result;
  }

  @override
  Future<String?> getHeliumUserId() async {
    final result = await methodChannel.invokeMethod<String?>('getHeliumUserId');
    return result;
  }

  @override
  Future<bool?> hideUpsell() async {
    final result = await methodChannel.invokeMethod<bool?>('hideUpsell');
    return result;
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) async {
    final result = await methodChannel.invokeMethod<String?>('overrideUserId', {
      'newUserId': newUserId,
      'traits': traits,
    });
    return result;
  }

  @override
  Future<bool?> paywallsLoaded() async {
    final result = await methodChannel.invokeMethod<bool?>('paywallsLoaded');
    return result;
  }

  @override
  Future<String?> presentUpsell({required String trigger}) async {
    final result = await methodChannel.invokeMethod<String?>(
      'presentUpsell',
      trigger,
    );
    return result;
  }
}
