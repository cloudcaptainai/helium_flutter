
class PaywallInfo {
  final String paywallTemplateName;
  final bool shouldShow;

  PaywallInfo({
    required this.paywallTemplateName,
    required this.shouldShow,
  });
}

class TriggerLoadingConfig {
  /// Whether to show loading state for this trigger. Set to null to use the global `useLoadingState` setting.
  final bool? useLoadingState;
  /// Maximum seconds to show loading for this trigger. Set to null to use the global `loadingBudget` setting.
  final double? loadingBudget;

  TriggerLoadingConfig({
    this.useLoadingState,
    this.loadingBudget,
  });

  Map<String, dynamic> toMap() {
    return {
      if (useLoadingState != null) 'useLoadingState': useLoadingState,
      if (loadingBudget != null) 'loadingBudget': loadingBudget,
    };
  }
}

class HeliumPaywallLoadingConfig {
  /// Whether to show a loading state while fetching paywall configuration.
  /// When true, shows a loading view for up to `loadingBudget` seconds before falling back.
  /// Default: true
  final bool useLoadingState;

  /// Maximum time (in seconds) to show the loading state before displaying fallback.
  /// After this timeout, the fallback view will be shown even if the paywall is still downloading.
  /// Default: 2.0 seconds
  final double loadingBudget;

  /// Optional per-trigger loading configuration overrides.
  /// Use this to customize loading behavior for specific triggers.
  /// Keys are trigger names, values are TriggerLoadingConfig instances.
  /// Example: Disable loading for "onboarding" trigger while keeping it for others.
  final Map<String, TriggerLoadingConfig>? perTriggerLoadingConfig;

  HeliumPaywallLoadingConfig({
    this.useLoadingState = true,
    this.loadingBudget = 2.0,
    this.perTriggerLoadingConfig,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'useLoadingState': useLoadingState,
      'loadingBudget': loadingBudget,
    };

    if (perTriggerLoadingConfig != null) {
      final perTriggerMap = <String, Map<String, dynamic>>{};
      perTriggerLoadingConfig!.forEach((key, value) {
        perTriggerMap[key] = value.toMap();
      });
      map['perTriggerLoadingConfig'] = perTriggerMap;
    }

    return map;
  }
}

// Event handler types for per-presentation event handling
abstract class PaywallEventHandlers {
  void Function(PaywallOpenEvent event)? get onOpen;
  void Function(PaywallCloseEvent event)? get onClose;
  void Function(PaywallDismissedEvent event)? get onDismissed;
  void Function(PurchaseSucceededEvent event)? get onPurchaseSucceeded;
}

class PaywallEventHandlersImpl implements PaywallEventHandlers {
  @override
  final void Function(PaywallOpenEvent event)? onOpen;
  @override
  final void Function(PaywallCloseEvent event)? onClose;
  @override
  final void Function(PaywallDismissedEvent event)? onDismissed;
  @override
  final void Function(PurchaseSucceededEvent event)? onPurchaseSucceeded;

  PaywallEventHandlersImpl({
    this.onOpen,
    this.onClose,
    this.onDismissed,
    this.onPurchaseSucceeded,
  });
}

// Typed event interfaces
class PaywallOpenEvent {
  final String type = 'paywallOpen';
  final String triggerName;
  final String paywallName;
  final bool isSecondTry;
  final String? viewType;

  PaywallOpenEvent({
    required this.triggerName,
    required this.paywallName,
    required this.isSecondTry,
    this.viewType,
  });
}

class PaywallCloseEvent {
  final String type = 'paywallClose';
  final String triggerName;
  final String paywallName;
  final bool isSecondTry;

  PaywallCloseEvent({
    required this.triggerName,
    required this.paywallName,
    required this.isSecondTry,
  });
}

class PaywallDismissedEvent {
  final String type = 'paywallDismissed';
  final String triggerName;
  final String paywallName;
  final bool isSecondTry;

  PaywallDismissedEvent({
    required this.triggerName,
    required this.paywallName,
    required this.isSecondTry,
  });
}

class PurchaseSucceededEvent {
  final String type = 'purchaseSucceeded';
  final String productId;
  final String triggerName;
  final String paywallName;
  final bool isSecondTry;

  PurchaseSucceededEvent({
    required this.productId,
    required this.triggerName,
    required this.paywallName,
    required this.isSecondTry,
  });
}

class PresentUpsellParams {
  final String triggerName;
  final PaywallEventHandlers? eventHandlers;
  final Map<String, dynamic>? customPaywallTraits;

  PresentUpsellParams({
    required this.triggerName,
    this.eventHandlers,
    this.customPaywallTraits,
  });
}

// Enhanced HeliumPaywallEvent with new types and deprecated annotations
class HeliumPaywallEvent {
  final String type;
  final String? triggerName;
  final String? paywallName;
  /// @deprecated Use `paywallName` instead.
  final String? paywallTemplateName;
  final String? productId;
  /// @deprecated Use `productId` instead.
  final String? productKey;
  final String? buttonName;
  /// @deprecated Use `buttonName` instead.
  final String? ctaName;
  final String? configId;
  final String? impressionId;
  final int? responseTimeMs;
  final int? configDownloadTimeMs;
  final int? fontsDownloadTimeTakenMS;
  final int? bundleDownloadTimeMS;
  final bool? dismissAll;
  final bool? isSecondTry;
  final String? error;
  /// @deprecated Use `error` instead.
  final String? errorDescription;
  /// Unix timestamp in seconds
  final int? timestamp;

  HeliumPaywallEvent({
    required this.type,
    this.triggerName,
    this.paywallName,
    this.paywallTemplateName,
    this.productId,
    this.productKey,
    this.ctaName,
    this.configId,
    this.impressionId,
    this.responseTimeMs,
    this.configDownloadTimeMs,
    this.fontsDownloadTimeTakenMS,
    this.bundleDownloadTimeMS,
    this.dismissAll,
    this.isSecondTry,
    this.error,
    this.errorDescription,
    this.timestamp,
  });

  factory HeliumPaywallEvent.fromMap(Map<String, dynamic> map) {
    return HeliumPaywallEvent(
      type: map['type'] ?? '',
      triggerName: map['triggerName'],
      paywallName: map['paywallName'],
      paywallTemplateName: map['paywallTemplateName'],
      productId: map['productId'],
      productKey: map['productKey'],
      ctaName: map['ctaName'],
      configId: map['configId'],
      impressionId: map['impressionId'],
      responseTimeMs: map['responseTimeMs'],
      configDownloadTimeMs: map['configDownloadTimeMs'],
      fontsDownloadTimeTakenMS: map['fontsDownloadTimeTakenMS'],
      bundleDownloadTimeMS: map['bundleDownloadTimeMS'],
      dismissAll: map['dismissAll'],
      isSecondTry: map['isSecondTry'],
      error: map['error'],
      errorDescription: map['errorDescription'],
      timestamp: map['timestamp'],
    );
  }
}
