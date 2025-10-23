
class PaywallInfo {
  final String paywallTemplateName;
  final bool shouldShow;

  PaywallInfo({
    required this.paywallTemplateName,
    required this.shouldShow,
  });
}

class CanPresentUpsellResult {
  final Map<String, dynamic> _data;

  CanPresentUpsellResult.fromMap(Map<String, dynamic> map) : _data = map;

  bool get canShow => _data['canShow'] as bool? ?? false;
  bool? get isFallback => _data['isFallback'] as bool?;
  String? get paywallUnavailableReason => _data['paywallUnavailableReason'] as String?;
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
class PaywallEventHandlers {
  final void Function(PaywallOpenEvent event)? onOpen;
  final void Function(PaywallCloseEvent event)? onClose;
  final void Function(PaywallDismissedEvent event)? onDismissed;
  final void Function(PurchaseSucceededEvent event)? onPurchaseSucceeded;
  final void Function(PaywallOpenFailedEvent event)? onOpenFailed;
  final void Function(CustomPaywallActionEvent event)? onCustomPaywallAction;

  PaywallEventHandlers({
    this.onOpen,
    this.onClose,
    this.onDismissed,
    this.onPurchaseSucceeded,
    this.onOpenFailed,
    this.onCustomPaywallAction,
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

class PaywallOpenFailedEvent {
  final String type = 'paywallOpenFailed';
  final String triggerName;
  final String paywallName;
  final String error;
  final String? paywallUnavailableReason;
  final bool isSecondTry;

  PaywallOpenFailedEvent({
    required this.triggerName,
    required this.paywallName,
    required this.error,
    required this.paywallUnavailableReason,
    required this.isSecondTry,
  });
}

class CustomPaywallActionEvent {
  final String type = 'customPaywallAction';
  final String triggerName;
  final String paywallName;
  final String actionName;
  final Map<String, dynamic> params;
  final bool isSecondTry;

  CustomPaywallActionEvent({
    required this.triggerName,
    required this.paywallName,
    required this.actionName,
    required this.params,
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
  final Map<String, dynamic> _data;

  HeliumPaywallEvent.fromMap(Map<String, dynamic> map) : _data = map;

  Map<String, dynamic>? getSafeData(dynamic paramsData) {
    if (paramsData == null) {
      return null;
    }
    if (paramsData is Map<String, dynamic>) {
      return paramsData;
    }
    if (paramsData is Map) {
      try {
        // Use collection's DelegatingMap for deep casting
        return paramsData.cast<String, dynamic>();
      } catch (e) {
        // If cast fails (note - only one level deep)
        final result = <String, dynamic>{};
        paramsData.forEach((key, value) {
          if (key is String) {
            result[key] = value;
          }
        });
        return result;
      }
    }
    return null;
  }

  // Type-safe getters
  Map<String, dynamic> get rawData => _data;
  String get type => _data['type'] ?? '';
  String? get triggerName => _data['triggerName'];
  String? get paywallName => _data['paywallName'];
  String? get productId => _data['productId'];
  String? get buttonName => _data['buttonName'];
  String? get configId => _data['configId'];
  String? get impressionId => _data['impressionId'];
  int? get responseTimeMs => _data['responseTimeMs'];
  int? get configDownloadTimeMs => _data['configDownloadTimeMs'];
  int? get fontsDownloadTimeTakenMS => _data['fontsDownloadTimeTakenMS'];
  int? get bundleDownloadTimeMS => _data['bundleDownloadTimeMS'];
  bool? get dismissAll => _data['dismissAll'];
  bool? get isSecondTry => _data['isSecondTry'];
  String? get error => _data['error'];
  String? get paywallUnavailableReason => _data['paywallUnavailableReason'];
  String? get customPaywallActionName => _data['actionName'];
  Map<String, dynamic>? get customPaywallActionParams => getSafeData(_data['params']);
  /// Unix timestamp in seconds
  int? get timestamp => _data['timestamp'];

  // Deprecated getters for backwards compatibility
  /// @deprecated Use `paywallName` instead.
  String? get paywallTemplateName => _data['paywallTemplateName'];
  /// @deprecated Use `productId` instead.
  String? get productKey => _data['productKey'];
  /// @deprecated Use `buttonName` instead.
  String? get ctaName => _data['ctaName'];
  /// @deprecated Use `error` instead.
  String? get errorDescription => _data['errorDescription'];
}
