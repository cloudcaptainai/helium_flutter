import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_environment.dart';
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
  bool get isInitialized => _isInitialized;

  Map<String, dynamic> _buildNativeArgs({
    required String apiKey,
    HeliumPurchaseDelegate? purchaseDelegate,
    String? customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
    String? revenueCatAppUserId,
    String? fallbackBundleAssetPath,
    HeliumEnvironment? environment,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
    Set<String>? androidConsumableProductIds,
  }) {
    return {
      'apiKey': apiKey,
      'customUserId': customUserId,
      'customAPIEndpoint': customAPIEndpoint,
      'customUserTraits': _convertBooleansToMarkers(customUserTraits),
      'revenueCatAppUserId': revenueCatAppUserId,
      'fallbackAssetPath': fallbackBundleAssetPath ?? "helium-fallbacks.json",
      'environment': environment?.name,
      'paywallLoadingConfig':
          _convertBooleansToMarkers(paywallLoadingConfig?.toMap()),
      'useDefaultDelegate': purchaseDelegate == null,
      'wrapperSdkVersion': heliumFlutterSdkVersion,
      'delegateType': purchaseDelegate?.delegateType,
      'androidConsumableProductIds': androidConsumableProductIds?.toList(),
    };
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
    _setMethodCallHandlers(callbacks, purchaseDelegate);
    _fallbackPaywallWidget = fallbackPaywall;

    if (_isInitialized) {
      return "[Helium] Already initialized!";
    }
    _isInitialized = true;

    try {
      final result =
          await methodChannel.invokeMethod<String?>(setupCoreMethodName,
              _buildNativeArgs(
                apiKey: apiKey,
                purchaseDelegate: purchaseDelegate,
                customAPIEndpoint: customAPIEndpoint,
                customUserId: customUserId,
                customUserTraits: customUserTraits,
                revenueCatAppUserId: revenueCatAppUserId,
                fallbackBundleAssetPath: fallbackBundleAssetPath,
                environment: environment,
                paywallLoadingConfig: paywallLoadingConfig,
                androidConsumableProductIds: androidConsumableProductIds,
              ));
      return result;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
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
    _setMethodCallHandlers(callbacks, purchaseDelegate);
    _fallbackPaywallWidget = fallbackPaywall;

    if (_isInitialized) {
      return "[Helium] Already initialized!";
    }
    _isInitialized = true;

    try {
      final result =
          await methodChannel.invokeMethod<String?>(initializeMethodName,
              _buildNativeArgs(
                apiKey: apiKey,
                purchaseDelegate: purchaseDelegate,
                customAPIEndpoint: customAPIEndpoint,
                customUserId: customUserId,
                customUserTraits: customUserTraits,
                revenueCatAppUserId: revenueCatAppUserId,
                fallbackBundleAssetPath: fallbackBundleAssetPath,
                environment: environment,
                paywallLoadingConfig: paywallLoadingConfig,
                androidConsumableProductIds: androidConsumableProductIds,
              ));
      return result;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
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
        String productId = '';
        String? basePlanId;
        String? offerId;

        if (handler.arguments is String) {
          productId = handler.arguments as String;
        } else if (handler.arguments is Map) {
          final args = handler.arguments as Map;
          productId = args['productId'] as String? ?? '';
          basePlanId = args['basePlanId'] as String?;
          offerId = args['offerId'] as String?;
        }

        HeliumPurchaseResult result;
        if (Platform.isAndroid) {
          result = await purchaseDelegate.makePurchaseAndroid(productId,
              basePlanId: basePlanId, offerId: offerId);
        } else if (Platform.isIOS) {
          result = await purchaseDelegate.makePurchaseIOS(productId);
        } else {
          // ignore: deprecated_member_use_from_same_package
          result = await purchaseDelegate.makePurchase(productId);
        }

        return {
          'status': result.status.name,
          'error': result.error,
          'transactionId': result.transactionId,
          'originalTransactionId': result.originalTransactionId,
          'productId': result.productId,
        };
      } else if (handler.method == restorePurchasesMethodName) {
        if (purchaseDelegate == null) {
          return false;
        }
        final success = await purchaseDelegate.restorePurchases();
        return success;
      } else if (handler.method == onPaywallEventMethodName) {
        final dynamic args = handler.arguments;
        final Map<String, dynamic> eventMap =
            (args is Map) ? Map<String, dynamic>.from(args) : {};
        HeliumPaywallEvent event = HeliumPaywallEvent.fromMap(eventMap);
        _handlePaywallEvent(event);
        if (purchaseDelegate is HeliumCallbacks) {
          try {
            (purchaseDelegate as HeliumCallbacks).onPaywallEvent(event);
          } catch (e) {
            log('[Helium] Error in purchaseDelegate.onPaywallEvent: $e');
          }
        }
        try {
          callbacks?.onPaywallEvent(event);
        } catch (e) {
          log('[Helium] Error in callbacks.onPaywallEvent: $e');
        }
      } else if (handler.method == onPaywallEventHandlerMethodName) {
        final dynamic args = handler.arguments;
        final Map<String, dynamic> eventDict =
            (args is Map) ? Map<String, dynamic>.from(args) : {};
        _handlePaywallEventHandlers(HeliumPaywallEvent.fromMap(eventDict));
      } else if (handler.method == onHeliumLogEventMethodName) {
        final dynamic args = handler.arguments;
        final Map<String, dynamic> eventMap =
            (args is Map) ? Map<String, dynamic>.from(args) : {};
        _handleLogEvent(eventMap);
      } else {
        log('[Helium] Unknown method from MethodChannel: ${handler.method}');
      }
    });
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
    if (_isFallbackSheetShowing &&
        _fallbackContext != null &&
        _fallbackContext!.mounted) {
      Navigator.of(_fallbackContext!).pop();
    }
    return result ?? false;
  }

  @override
  Future<bool> hideAllUpsells() async {
    final result = await methodChannel.invokeMethod<bool>(
      hideAllUpsellsMethodName,
    );
    // Hide fallback sheet if it is displaying
    if (_isFallbackSheetShowing &&
        _fallbackContext != null &&
        _fallbackContext!.mounted) {
      Navigator.of(_fallbackContext!).pop();
    }
    return result ?? false;
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    Map<String, dynamic>? traits,
  }) async {
    final result = await methodChannel.invokeMethod<String?>(
      overrideUserIdMethodName,
      {'newUserId': newUserId, 'traits': _convertBooleansToMarkers(traits)},
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
    if (_isFallbackSheetShowing) {
      return; // already showing!
    }
    if (_fallbackPaywallWidget == null) {
      return; // no fallback provided, don't show anything
    }
    final context = _fallbackContext;
    if (context == null || !context.mounted) {
      _fallbackContext = null;
      return;
    }

    _isFallbackSheetShowing = true;

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
    }
  }

  @override
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    bool? dontShowIfAlreadyEntitled,
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
          'dontShowIfAlreadyEntitled': dontShowIfAlreadyEntitled,
        },
      );
      return result;
    } on PlatformException catch (e) {
      log('[Helium] Unexpected present upsell error: ${e.message}');
      _currentEventHandlers = null;
      await methodChannel.invokeMethod<String?>(
        fallbackOpenEventMethodName,
        {
          'trigger': trigger,
          'viewType': 'presented',
          'paywallUnavailableReason': 'bridgingError',
        },
      );
      _showFallbackSheet(trigger);
      return "Failed to present upsell: '${e.message}'.";
    }
  }

  @override
  Future<PaywallInfo?> getPaywallInfo(String trigger) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getPaywallInfo', trigger);

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

  Future<CanPresentUpsellResult?> canPresentUpsell(String trigger) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      canPresentUpsellMethodName,
      trigger,
    );
    if (result == null) {
      return null;
    }
    return CanPresentUpsellResult.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<bool> handleDeepLink(String uri) async {
    final result =
        await methodChannel.invokeMethod<bool>('handleDeepLink', uri);
    log('[Helium] Handled deep link: $result');
    return result ?? false;
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

  @override
  Future<bool?> hasEntitlementForPaywall(String trigger) async {
    final result = await methodChannel.invokeMethod<bool?>(
      hasEntitlementForPaywallMethodName,
      trigger,
    );
    return result;
  }

  @override
  Future<ExperimentInfo?> getExperimentInfoForTrigger(String trigger) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      getExperimentInfoForTriggerMethodName,
      trigger,
    );
    if (result == null) {
      return null;
    }
    return ExperimentInfo.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  void disableRestoreFailedDialog() {
    methodChannel.invokeMethod<void>(
      disableRestoreFailedDialogMethodName,
    );
  }

  @override
  void setCustomRestoreFailedStrings({
    String? customTitle,
    String? customMessage,
    String? customCloseButtonText,
  }) {
    methodChannel.invokeMethod<void>(
      setCustomRestoreFailedStringsMethodName,
      {
        'customTitle': customTitle,
        'customMessage': customMessage,
        'customCloseButtonText': customCloseButtonText,
      },
    );
  }

  @override
  Future<void> resetHelium({
    bool clearUserTraits = true,
    bool clearExperimentAllocations = false,
  }) async {
    // Dismiss fallback sheet if it is displaying
    if (_isFallbackSheetShowing &&
        _fallbackContext != null &&
        _fallbackContext!.mounted) {
      Navigator.of(_fallbackContext!).pop();
    }

    _fallbackPaywallWidget = null;
    _isFallbackSheetShowing = false;
    _fallbackContext = null;
    _currentEventHandlers = null;
    // Reset native SDK state
    try {
      await methodChannel.invokeMethod<void>(
        resetHeliumMethodName,
        {
          'clearUserTraits': clearUserTraits,
          'clearHeliumEventListeners': true,
          'clearExperimentAllocations': clearExperimentAllocations,
        },
      );
    } catch (e) {
      // Native reset likely completed; the async bridge response may have been
      // lost (e.g. during module teardown). Dart state is cleaned up regardless.
      log('[Helium] resetHelium did not receive native completion: $e');
    } finally {
      _isInitialized = false;
    }
  }

  @override
  void setLightDarkModeOverride(HeliumLightDarkMode mode) {
    methodChannel.invokeMethod<void>(
      setLightDarkModeOverrideMethodName,
      mode.name,
    );
  }

  @override
  void setRevenueCatAppUserId(String rcAppUserId) {
    methodChannel.invokeMethod<void>(
      setRevenueCatAppUserIdMethodName,
      rcAppUserId,
    );
  }

  @override
  Future<void> setThirdPartyAnalyticsAnonymousId(String? anonymousId) async {
    try {
      await methodChannel.invokeMethod<void>(
        setThirdPartyAnalyticsAnonymousIdMethodName,
        anonymousId,
      );
    } catch (e) {
      log('[Helium] Failed to set third-party analytics anonymous ID: $e');
    }
  }

  @override
  void setAndroidConsumableProductIds(Set<String> productIds) {
    if (!Platform.isAndroid) return;
    methodChannel.invokeMethod<void>(
      setAndroidConsumableProductIdsMethodName,
      productIds.toList(),
    );
  }

  @override
  Future<void> enableExternalWebCheckout({
    required String successURL,
    required String cancelURL,
    Set<HeliumWebCheckoutProcessor>? paymentProcessors,
  }) async {
    if (!Platform.isIOS) {
      log('[Helium] enableExternalWebCheckout is only available on iOS');
      return;
    }
    if (paymentProcessors != null && paymentProcessors.isEmpty) {
      log('[Helium] enableExternalWebCheckout: paymentProcessors must not be empty. '
          'Omit it to enable all, or pass {HeliumWebCheckoutProcessor.paddle} or {HeliumWebCheckoutProcessor.stripe}.');
      return;
    }
    try {
      await methodChannel.invokeMethod<void>(
        enableExternalWebCheckoutMethodName,
        {
          'successURL': successURL,
          'cancelURL': cancelURL,
          if (paymentProcessors != null)
            'paymentProcessors':
                paymentProcessors.map((p) => p.name).toList(),
        },
      );
    } catch (e) {
      log('[Helium] Failed to enable External Web Checkout: $e');
    }
  }

  @override
  Future<void> disableExternalWebCheckout() async {
    if (!Platform.isIOS) {
      log('[Helium] disableExternalWebCheckout is only available on iOS');
      return;
    }
    try {
      await methodChannel
          .invokeMethod<void>(disableExternalWebCheckoutMethodName);
    } catch (e) {
      log('[Helium] Failed to disable External Web Checkout: $e');
    }
  }

  @override
  Future<void> setAllowWebCheckoutWithoutUserId(bool allow) async {
    if (!Platform.isIOS) {
      log('[Helium] setAllowWebCheckoutWithoutUserId is only available on iOS');
      return;
    }
    try {
      await methodChannel.invokeMethod<void>(
        setAllowWebCheckoutWithoutUserIdMethodName,
        allow,
      );
    } catch (e) {
      log('[Helium] Failed to set allowWebCheckoutWithoutUserId: $e');
    }
  }

  @override
  Future<bool> hasActiveStripeEntitlement() async {
    if (!Platform.isIOS) {
      log('[Helium] hasActiveStripeEntitlement is only available on iOS');
      return false;
    }
    try {
      final result = await methodChannel.invokeMethod<bool>(
        hasActiveStripeEntitlementMethodName,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      log('[Helium] Failed to check Stripe entitlement: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> hasActivePaddleEntitlement() async {
    if (!Platform.isIOS) {
      log('[Helium] hasActivePaddleEntitlement is only available on iOS');
      return false;
    }
    try {
      final result = await methodChannel.invokeMethod<bool>(
        hasActivePaddleEntitlementMethodName,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      log('[Helium] Failed to check Paddle entitlement: ${e.message}');
      return false;
    }
  }

  @override
  Future<String?> createStripePortalSession({required String returnUrl}) async {
    if (!Platform.isIOS) {
      log('[Helium] createStripePortalSession is only available on iOS');
      return null;
    }
    try {
      return await methodChannel.invokeMethod<String>(
        createStripePortalSessionMethodName,
        returnUrl,
      );
    } on PlatformException catch (e) {
      log('[Helium] Failed to create Stripe portal session: ${e.message}');
      return null;
    }
  }

  @override
  Future<String?> createPaddlePortalSession() async {
    if (!Platform.isIOS) {
      log('[Helium] createPaddlePortalSession is only available on iOS');
      return null;
    }
    try {
      return await methodChannel.invokeMethod<String>(
        createPaddlePortalSessionMethodName,
      );
    } on PlatformException catch (e) {
      log('[Helium] Failed to create Paddle portal session: ${e.message}');
      return null;
    }
  }

  @override
  Future<void> resetStripeEntitlements() async {
    if (!Platform.isIOS) {
      log('[Helium] resetStripeEntitlements is only available on iOS');
      return;
    }
    try {
      await methodChannel.invokeMethod<void>(resetStripeEntitlementsMethodName);
    } on PlatformException catch (e) {
      log('[Helium] Failed to reset Stripe entitlements: ${e.message}');
    }
  }

  @override
  Future<void> resetPaddleEntitlements() async {
    if (!Platform.isIOS) {
      log('[Helium] resetPaddleEntitlements is only available on iOS');
      return;
    }
    try {
      await methodChannel.invokeMethod<void>(resetPaddleEntitlementsMethodName);
    } on PlatformException catch (e) {
      log('[Helium] Failed to reset Paddle entitlements: ${e.message}');
    }
  }

  @override
  Future<bool> handleURL(String url) async {
    if (!Platform.isIOS) {
      return false;
    }
    try {
      final result = await methodChannel.invokeMethod<bool>(
        handleURLMethodName,
        url,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      log('[Helium] Failed to handle URL: ${e.message}');
      return false;
    }
  }

  void _handlePaywallEventHandlers(HeliumPaywallEvent event) {
    if (_currentEventHandlers == null) return;

    final eventType = event.type;
    final triggerName = event.triggerName ?? 'unknown';
    final paywallName = event.paywallName ?? 'unknown';
    final isSecondTry = event.isSecondTry ?? false;

    switch (eventType) {
      case 'paywallOpen':
        _currentEventHandlers?.onOpen?.call(PaywallOpenEvent(
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
          viewType: 'presented',
          paywallUnavailableReason: event.paywallUnavailableReason,
          loadTimeTakenMS: event.loadTimeTakenMS,
          loadingBudgetMS: event.loadingBudgetMS,
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
        final productId = event.productId ?? 'unknown';
        _currentEventHandlers?.onPurchaseSucceeded?.call(PurchaseSucceededEvent(
          productId: productId,
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
          paymentProcessor: event.paymentProcessor,
        ));
        break;
      case 'paywallOpenFailed':
        _currentEventHandlers?.onOpenFailed?.call(PaywallOpenFailedEvent(
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
          error: event.error ?? '',
          paywallUnavailableReason: event.paywallUnavailableReason ?? '',
          loadTimeTakenMS: event.loadTimeTakenMS,
          loadingBudgetMS: event.loadingBudgetMS,
        ));
        break;
      case 'customPaywallAction':
        _currentEventHandlers?.onCustomPaywallAction
            ?.call(CustomPaywallActionEvent(
          triggerName: triggerName,
          paywallName: paywallName,
          isSecondTry: isSecondTry,
          actionName: event.customPaywallActionName ?? '',
          params: event.customPaywallActionParams ?? {},
        ));
        break;
    }
    _currentEventHandlers?.onAnyEvent?.call(event);
  }

  /// Routes native SDK log events to the appropriate log method.
  /// Log levels: 1=error, 2=warn, 3=info, 4=debug, 5=trace
  void _handleLogEvent(Map<String, dynamic> eventMap) {
    final int level = eventMap['level'] as int? ?? 4;
    final String message = eventMap['message'] as String? ?? '';
    final metadata = eventMap['metadata'] as Map?;

    // Build output string with metadata if present and non-empty
    String output = message;
    if (metadata != null && metadata.isNotEmpty) {
      output = '$message $metadata';
    }

    switch (level) {
      case 1: // error
        log('e $output');
        break;
      case 2: // warn
        log('w $output');
        break;
      case 3: // info
        log('i $output');
        break;
      case 4: // debug
      case 5: // trace
      default:
        log('d $output');
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
        final unavailableReason = heliumPaywallEvent.paywallUnavailableReason;
        if (trigger != null &&
            unavailableReason != "alreadyPresented" &&
            unavailableReason != "secondTryNoMatch") {
          // Dispatch on next frame to let event handling finish processing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFallbackSheet(trigger);
          });
        }
        break;
    }
  }

  @override
  Widget getUpsellWidget({
    required String trigger,
    PaywallEventHandlers? eventHandlers,
  }) {
    _currentEventHandlers = eventHandlers;
    return UpsellWrapperWidget(
      trigger: trigger,
      fallbackPaywallWidget:
          _fallbackPaywallWidget ?? Text("No fallback view provided"),
      availabilityChecker: () => canPresentUpsell(trigger),
      onFallbackOpened: (String? paywallUnavailableReason) async {
        await methodChannel.invokeMethod<String?>(
          fallbackOpenEventMethodName,
          {
            'trigger': trigger,
            'viewType': 'embedded',
            'paywallUnavailableReason': paywallUnavailableReason,
          },
        );
      },
      onFallbackClosed: () async {
        await methodChannel.invokeMethod<String?>(
          fallbackCloseEventMethodName,
          {
            'trigger': trigger,
            'viewType': 'embedded',
          },
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

    final result = <String, dynamic>{};
    for (final entry in input.entries) {
      // Strip null values — native SDKs ignore them and it complicates bridging code
      // (at least on expo, and this keeps logic consistent with expo)
      if (entry.value == null) continue;
      result[entry.key] = _convertValueBooleansToMarkers(entry.value);
    }
    return result;
  }

  /// Helper to recursively convert booleans in any value type
  dynamic _convertValueBooleansToMarkers(dynamic value) {
    if (value is bool) {
      return value
          ? "__helium_flutter_bool_true__"
          : "__helium_flutter_bool_false__";
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
  final Future<CanPresentUpsellResult?> Function() availabilityChecker;
  final void Function(String? paywallUnavailableReason)? onFallbackOpened;
  final VoidCallback? onFallbackClosed;

  const UpsellWrapperWidget({
    super.key,
    required this.trigger,
    required this.fallbackPaywallWidget,
    required this.availabilityChecker,
    this.onFallbackOpened,
    this.onFallbackClosed,
  });

  @override
  State<UpsellWrapperWidget> createState() => _UpsellWrapperWidgetState();
}

class _UpsellWrapperWidgetState extends State<UpsellWrapperWidget> {
  late Future<CanPresentUpsellResult?> _availabilityFuture;
  bool _fallbackShown = false;

  @override
  void initState() {
    super.initState();
    _availabilityFuture = widget.availabilityChecker();
  }

  void _onShowFallback(String? paywallUnavailableReason) {
    if (!_fallbackShown) {
      _fallbackShown = true;
      widget.onFallbackOpened?.call(paywallUnavailableReason);
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
    return FutureBuilder<CanPresentUpsellResult?>(
      future: _availabilityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.data?.canShow == true) {
          return UpsellViewForTrigger(trigger: widget.trigger);
        } else {
          _onShowFallback(snapshot.data?.paywallUnavailableReason);
          return widget.fallbackPaywallWidget;
        }
      },
    );
  }
}

///This widget used to present view based on [trigger]
class UpsellViewForTrigger extends StatelessWidget {
  const UpsellViewForTrigger({super.key, required this.trigger});
  final String viewType = upsellViewForTrigger;
  final String trigger;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return AndroidView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: {'trigger': trigger},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: {'trigger': trigger},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const Text('Unsupported platform for Helium upsell view');
    }
  }
}
