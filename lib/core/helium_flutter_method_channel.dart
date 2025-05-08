import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import 'helium_flutter_platform.dart';

/// An implementation of [HeliumFlutterPlatform] that uses method channels.
class HeliumFlutterMethodChannel extends HeliumFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  MethodChannel methodChannel = const MethodChannel(heliumFlutter);

  late Widget fallbackPaywallWidget;

  @override
  Future<String?> initialize({
    required HeliumCallbacks callbacks,
    required Widget fallbackPaywall,
    required String apiKey,
    required String customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
  }) async {
    _setMethodCallHandlers(callbacks);
    fallbackPaywallWidget = fallbackPaywall;
    final result = await methodChannel
        .invokeMethod<String?>(initializeMethodName, {
      'apiKey': apiKey,
      'customUserId': customUserId,
      'customAPIEndpoint': customAPIEndpoint,
      'customUserTraits': customUserTraits,
    });
    return result;
  }

  void _setMethodCallHandlers(HeliumCallbacks callbacks) {
    methodChannel.setMethodCallHandler((handler) async {
      if (handler.method == makePurchaseMethodName) {
        String id = handler.arguments as String? ?? '';
        final status = await callbacks.makePurchase(id);
        return status.name;
      } else if (handler.method == restorePurchasesMethodName) {
        bool status = handler.arguments as bool? ?? false;
        callbacks.restorePurchases(status);
      } else if (handler.method == onPaywallEventMethodName) {
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
      getDownloadStatusMethodName,
    );
    return result;
  }

  @override
  Future<String?> getHeliumUserId() async {
    final result = await methodChannel.invokeMethod<String?>(
      getHeliumUserIdMethodName,
    );
    return result;
  }

  @override
  Future<bool?> hideUpsell() async {
    final result = await methodChannel.invokeMethod<bool?>(
      hideUpsellMethodName,
    );
    return result;
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) async {
    final result = await methodChannel.invokeMethod<String?>(
      overrideUserIdMethodName,
      {'newUserId': newUserId, 'traits': traits},
    );
    return result;
  }

  @override
  Future<bool?> paywallsLoaded() async {
    final result = await methodChannel.invokeMethod<bool?>(
      paywallsLoadedMethodName,
    );
    return result;
  }

  @override
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
  }) async {
    void showUpsellModal(BuildContext ctx) {
      showModalBottomSheet(
        context: ctx,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) {
          return SizedBox.expand(
            child: fallbackPaywallWidget,
          );
        },
      );
    }

    final downloadStatus = await getDownloadStatus();
    if (downloadStatus != 'success') {
      if (context.mounted) {
        showUpsellModal(context);
      }
      return 'Unsuccessful Helium download';
    }

    try {
      final result = await methodChannel.invokeMethod<String?>(
        presentUpsellMethodName,
        trigger,
      );
      return result;
    } on PlatformException catch (e) {
      if (context.mounted) {
        showUpsellModal(context);
      }
      return "Failed to present upsell: '${e.message}'.";
    }
  }
}
