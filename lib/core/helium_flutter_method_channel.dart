import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import '../types/helium_transaction_status.dart';
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
    HeliumCallbacks? callbacks,
    HeliumPurchaseDelegate? purchaseDelegate,
    Widget? fallbackPaywall,
    String? customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
    String? revenueCatAppUserId,
    String? fallbackBundleAssetPath,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
  }) async {
    _setMethodCallHandlers(callbacks, purchaseDelegate);
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
      'customUserTraits': _convertBooleansToMarkers(customUserTraits),
      'revenueCatAppUserId': revenueCatAppUserId,
      'fallbackAssetPath': fallbackBundleAssetPath,
      'paywallLoadingConfig': _convertBooleansToMarkers(paywallLoadingConfig?.toMap()),
      'useDefaultDelegate': purchaseDelegate == null,
    });
    return result;
  }

  void _setMethodCallHandlers(
    HeliumCallbacks? callbacks,
    HeliumPurchaseDelegate? purchaseDelegate,
  ) {
    methodChannel.setMethodCallHandler((handler) async {
      if (handler.method == makePurchaseMethodName) {
        if (purchaseDelegate == null) {
          return {
            'status': HeliumTransactionStatus.failed,
            'error': 'No purchase delegate found.',
          };
        }
        String id = handler.arguments as String? ?? '';
        final result = await purchaseDelegate.makePurchase(id);

        return {
          'status': result.status.name,
          'error': result.error,
        };
      } else if (handler.method == restorePurchasesMethodName) {
        if (purchaseDelegate == null) {
          return false;
        }
        final success = await purchaseDelegate.restorePurchases();
        return success;
      } else if (handler.method == onPaywallEventMethodName) {
        final dynamic args = handler.arguments;
        final Map<String, dynamic> eventMap = (args is Map)
            ? Map<String, dynamic>.from(args)
            : {};
        HeliumPaywallEvent event = HeliumPaywallEvent.fromMap(eventMap);
        _handlePaywallEvent(event);
        callbacks?.onPaywallEvent(event);
      } else if (handler.method == onPaywallEventHandlerMethodName) {
        final dynamic args = handler.arguments;
        final Map<String, dynamic> eventDict = (args is Map)
            ? Map<String, dynamic>.from(args)
            : {};
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

  Future<void> _showFallbackSheet(String trigger) async {
    if (_isFallbackSheetShowing) return; // already showing!
    final context = _fallbackContext;
    if (context == null || !context.mounted) {
      _fallbackContext = null;
      return;
    }

    _isFallbackSheetShowing = true;

    methodChannel.invokeMethod<String?>(
      fallbackOpenEventMethodName,
      {'trigger': trigger, 'viewType': 'presented'},
    );

    try {
      await showModalBottomSheet(
        context: context,
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

  @override
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
  }) async {
    _fallbackContext = context;

    // Store current event handlers
    _currentEventHandlers = eventHandlers;

    try {
      final result = await methodChannel.invokeMethod<String?>(
        presentUpsellMethodName,
        {
          'trigger': trigger,
          'customPaywallTraits': _convertBooleansToMarkers(customPaywallTraits),
        },
      );
      return result;
    } on PlatformException catch (e) {
      log('[Helium] Unexpected present upsell error: ${e.message}');
      _currentEventHandlers = null;
      _showFallbackSheet(trigger);
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

  @override
  Future<bool?> hasEntitlementForPaywall(String trigger) async {
    final result = await methodChannel.invokeMethod<bool?>(
      hasEntitlementForPaywallMethodName,
      trigger,
    );
    return result;
  }

  @override
  Future<bool> hasAnyActiveSubscription() async {
    final result = await methodChannel.invokeMethod<bool?>(
      hasAnyActiveSubscriptionMethodName,
    );
    return result ?? false;
  }

  @override
  Future<bool> hasAnyEntitlement() async {
    final result = await methodChannel.invokeMethod<bool?>(
      hasAnyEntitlementMethodName,
    );
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
    }
  }

  void _handlePaywallEvent(HeliumPaywallEvent heliumPaywallEvent) {
    final trigger = heliumPaywallEvent.triggerName;
    switch (heliumPaywallEvent.type) {
      case 'paywallClose':
        if (heliumPaywallEvent.isSecondTry != true) {
          _currentEventHandlers = null;
          _fallbackContext = null;
        }
        break;
      case 'paywallSkipped':
        _currentEventHandlers = null;
        _fallbackContext = null;
        break;
      case 'paywallOpenFailed':
        _currentEventHandlers = null;
        if (trigger != null) {
          // Dispatch on next frame since fallback can trigger new event/s
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFallbackSheet(trigger);
          });
        }
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

  /// Recursively converts boolean values to special marker strings to preserve
  /// type information when passing through platform channels.
  ///
  /// Flutter's platform channels convert booleans to NSNumber (0/1), making them
  /// indistinguishable from actual numeric values. This helper converts:
  /// - true -> "__helium_flutter_bool_true__"
  /// - false -> "__helium_flutter_bool_false__"
  /// - All other values remain unchanged
  Map<String, dynamic>? _convertBooleansToMarkers(Map<String, dynamic>? input) {
    if (input == null) return null;

    return input.map((key, value) => MapEntry(key, _convertValueBooleansToMarkers(value)));
  }

  /// Helper to recursively convert booleans in any value type
  dynamic _convertValueBooleansToMarkers(dynamic value) {
    if (value is bool) {
      return value ? "__helium_flutter_bool_true__" : "__helium_flutter_bool_false__";
    } else if (value is Map<String, dynamic>) {
      return _convertBooleansToMarkers(value);
    } else if (value is List) {
      return value.map(_convertValueBooleansToMarkers).toList();
    }
    return value;
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
        if (snapshot.data == 'downloadSuccess') {
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
