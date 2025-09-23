import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import '../types/helium_types.dart';
import 'helium_flutter_platform.dart';

/// An implementation of [HeliumFlutterPlatform] that uses method channels.
class HeliumFlutterMethodChannel extends HeliumFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  MethodChannel methodChannel = const MethodChannel(heliumFlutter);

  Widget? _fallbackPaywallWidget;
  bool _isFallbackSheetShowing = false;
  BuildContext? _fallbackContext;

  bool _isInitialized = false;
  PaywallEventHandlers? _currentEventHandlers;

  @override
  Future<String?> initialize({
    required String apiKey,
    required HeliumCallbacks callbacks,
    Widget? fallbackPaywall,
    String? customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
    String? revenueCatAppUserId,
    String? fallbackBundleAssetPath,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
  }) async {
    _setMethodCallHandlers(callbacks);
    _fallbackPaywallWidget = fallbackPaywall;
    
    if (_isInitialized) {
      return "[Helium] Already initialized!";
    }
    _isInitialized = true;

    final result = await methodChannel
        .invokeMethod<String?>(initializeMethodName, {
      'apiKey': apiKey,
      'customUserId': customUserId,
      'customAPIEndpoint': customAPIEndpoint,
      'customUserTraits': customUserTraits,
      'revenueCatAppUserId': revenueCatAppUserId,
      'fallbackAssetPath': fallbackBundleAssetPath,
      'paywallLoadingConfig': paywallLoadingConfig?.toMap(),
    });
    return result;
  }

  void _setMethodCallHandlers(HeliumCallbacks callbacks) {
    methodChannel.setMethodCallHandler((handler) async {
      if (handler.method == makePurchaseMethodName) {
        String id = handler.arguments as String? ?? '';
        final result = await callbacks.makePurchase(id);

        return {
          'status': result.status.name,
          'error': result.error,
        };
      } else if (handler.method == restorePurchasesMethodName) {
        final success = await callbacks.restorePurchases();
        return success;
      } else if (handler.method == onPaywallEventMethodName) {
        Map<String, dynamic> eventMap = handler.arguments as Map<String, dynamic>? ?? {};
        HeliumPaywallEvent event = HeliumPaywallEvent.fromMap(eventMap);
        callbacks.onPaywallEvent(event);
      } else if (handler.method == 'onPaywallEventHandler') {
        Map<String, dynamic> eventDict = handler.arguments as Map<String, dynamic>? ?? {};
        _handlePaywallEventHandlers(eventDict);
      } else {
        log('[Helium] Unknown method from MethodChannel: ${handler.method}');
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
  Future<bool> hideUpsell() async {
    final result = await methodChannel.invokeMethod<bool>(
      hideUpsellMethodName,
    );
    // Hide fallback sheet if it is displaying
    if (_isFallbackSheetShowing && _fallbackContext != null && _fallbackContext!.mounted) {
      Navigator.of(_fallbackContext!).pop();
    }
    return result ?? false;
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
  Future<bool> paywallsLoaded() async {
    final result = await methodChannel.invokeMethod<bool?>(
      paywallsLoadedMethodName,
    );
    return result ?? false;
  }

  @override
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
  }) async {
    Future<void> showFallbackSheet(BuildContext ctx) async {
      if (_isFallbackSheetShowing) return; // already showing!

      _isFallbackSheetShowing = true;
      _fallbackContext = context;

      methodChannel.invokeMethod<String?>(
        fallbackOpenEventMethodName,
        {'trigger': trigger, 'viewType': 'presented'},
      );

      try {
        await showModalBottomSheet(
          context: ctx,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) {
            return SizedBox.expand(
              child: _fallbackPaywallWidget ?? Text("No fallback view provided"),
            );
          },
        );
      } finally {
        _isFallbackSheetShowing = false;
        _fallbackContext = null;

        methodChannel.invokeMethod<String?>(
          fallbackCloseEventMethodName,
          {'trigger': trigger, 'viewType': 'presented'},
        );
      }
    }

    final canPresentResult = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      canPresentUpsellMethodName,
      trigger,
    );

    final bool canPresent = canPresentResult?['canPresent'] ?? false;
    final String reason = canPresentResult?['reason'] ?? 'method call failed';

    if (!canPresent) {
      log('[Helium] Cannot present trigger "$trigger". Reason: $reason');
      if (context.mounted) {
        showFallbackSheet(context);
      }
      return 'Cannot present upsell - $reason';
    }

    // Store current event handlers
    _currentEventHandlers = eventHandlers;

    try {
      final result = await methodChannel.invokeMethod<String?>(
        presentUpsellMethodName,
        {
          'trigger': trigger,
          'customPaywallTraits': customPaywallTraits,
        },
      );
      return result;
    } on PlatformException catch (e) {
      log('[Helium] Unexpected present upsell error: ${e.message}');
      _currentEventHandlers = null;
      if (context.mounted) {
        showFallbackSheet(context);
      }
      return "Failed to present upsell: '${e.message}'.";
    }
  }

  @override
  Future<PaywallInfo?> getPaywallInfo(String trigger) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>('getPaywallInfo', trigger);

    if (result == null) {
      log('[Helium] getPaywallInfo unexpected error.');
      return null;
    }
    if (result['errorMsg'] != null) {
      log('[Helium] ${result['errorMsg']}');
      return null;
    }

    return PaywallInfo(
      paywallTemplateName: result['templateName'] ?? 'unknown template',
      shouldShow: result['shouldShow'] ?? true,
    );
  }

  @override
  Future<bool> handleDeepLink(String uri) async {
    final result = await methodChannel.invokeMethod<bool>('handleDeepLink', uri);
    log('[Helium] Handled deep link: $result');
    return result ?? false;
  }

  void _handlePaywallEventHandlers(Map<String, dynamic> eventDict) {
    if (_currentEventHandlers == null) return;

    final eventType = eventDict['type'] as String?;
    final triggerName = eventDict['triggerName'] as String? ?? 'unknown';
    final paywallName = eventDict['paywallName'] as String? ?? 'unknown';
    final isSecondTry = eventDict['isSecondTry'] as bool? ?? false;

    switch (eventType) {
      case 'paywallOpen':
        _currentEventHandlers?.onOpen?.call(PaywallOpenEvent(
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
          viewType: 'presented',
        ));
        break;
      case 'paywallClose':
        _currentEventHandlers?.onClose?.call(PaywallCloseEvent(
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
        ));
        if (!isSecondTry) {
          _currentEventHandlers = null;
        }
        break;
      case 'paywallDismissed':
        _currentEventHandlers?.onDismissed?.call(PaywallDismissedEvent(
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
        ));
        break;
      case 'purchaseSucceeded':
        final productId = eventDict['productId'] as String? ?? 'unknown';
        _currentEventHandlers?.onPurchaseSucceeded?.call(PurchaseSucceededEvent(
          productId: productId,
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
        ));
        break;
      case 'paywallSkipped':
        _currentEventHandlers = null;
        break;
      case 'paywallOpenFailed':
        _currentEventHandlers = null;
        break;
    }
  }

  @override
  Widget getUpsellWidget({required String trigger}) {
    return UpsellWrapperWidget(
      trigger: trigger,
      fallbackPaywallWidget: _fallbackPaywallWidget ?? Text("No fallback view provided"),
      downloadStatusFetcher: getDownloadStatus, // Pass the actual async function
      onFallbackOpened: () async {
        await methodChannel.invokeMethod<String?>(
          fallbackOpenEventMethodName,
          {'trigger': trigger, 'viewType': 'embedded'},
        );
      },
      onFallbackClosed: () async {
        await methodChannel.invokeMethod<String?>(
          fallbackCloseEventMethodName,
          {'trigger': trigger, 'viewType': 'embedded'},
        );
      },
    );
  }

}

/// A wrapper widget that handles the asynchronous fetching of download status
/// and then displays the appropriate UI. Fetching download status should be
/// nearly synchronous.
class UpsellWrapperWidget extends StatefulWidget {
  final String trigger;
  final Widget fallbackPaywallWidget;
  final Future<String?> Function() downloadStatusFetcher;
  final VoidCallback? onFallbackOpened;
  final VoidCallback? onFallbackClosed;

  const UpsellWrapperWidget({
    super.key,
    required this.trigger,
    required this.fallbackPaywallWidget,
    required this.downloadStatusFetcher,
    this.onFallbackOpened,
    this.onFallbackClosed,
  });

  @override
  State<UpsellWrapperWidget> createState() => _UpsellWrapperWidgetState();
}
class _UpsellWrapperWidgetState extends State<UpsellWrapperWidget> {
  late Future<String?> _downloadStatusFuture;
  bool _fallbackShown = false;

  @override
  void initState() {
    super.initState();
    _downloadStatusFuture = widget.downloadStatusFetcher();
  }

  void _onShowFallback() {
    if (!_fallbackShown) {
      _fallbackShown = true;
      widget.onFallbackOpened?.call();
    }
  }

  @override
  void dispose() {
    if (_fallbackShown) {
      widget.onFallbackClosed?.call();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _downloadStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.data == '"downloadSuccess"') {
          return UpsellViewForTrigger(trigger: widget.trigger);
        } else {
          _onShowFallback();
          return widget.fallbackPaywallWidget;
        }
      },
    );
  }
}

///This widget used to present view based on [trigger]
class UpsellViewForTrigger extends StatelessWidget {
  const UpsellViewForTrigger({super.key, this.trigger});
  final String viewType = upsellViewForTrigger;
  final String? trigger;

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: trigger != null ? {'trigger': trigger} : {},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
