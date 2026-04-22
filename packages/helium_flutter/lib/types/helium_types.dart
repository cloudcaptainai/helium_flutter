/// Light/dark mode override for Helium paywalls
enum HeliumLightDarkMode {
  /// Force light mode
  light,
  /// Force dark mode
  dark,
  /// Use system setting (default)
  system,
}

/// Payment processors supported by External Web Checkout.
enum HeliumWebCheckoutProcessor {
  paddle,
  stripe,
}

/// Identifies which payment processor completed a purchase.
enum HeliumPaymentProcessor {
  appStore,
  stripe,
  paddle;

  static HeliumPaymentProcessor? fromValue(String? value) {
    if (value == null) return null;
    for (final p in HeliumPaymentProcessor.values) {
      if (p.name == value) return p;
    }
    return null;
  }
}

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

class HeliumPaywallLoadingConfig {
  /// Whether to show a loading state while fetching paywall configuration.
  /// When true, shows a loading view for up to `loadingBudget` seconds before falling back.
  /// Default: true
  final bool useLoadingState;

  /// Maximum time (in seconds) to show the loading state before displaying fallback.
  /// After this timeout, the fallback view will be shown even if the paywall is still downloading.
  /// Default: 7.0 seconds
  final double loadingBudget;

  HeliumPaywallLoadingConfig({
    this.useLoadingState = true,
    this.loadingBudget = 7.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'useLoadingState': useLoadingState,
      'loadingBudget': loadingBudget,
    };
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
  final void Function(HeliumPaywallEvent event)? onAnyEvent;

  PaywallEventHandlers({
    this.onOpen,
    this.onClose,
    this.onDismissed,
    this.onPurchaseSucceeded,
    this.onOpenFailed,
    this.onCustomPaywallAction,
    this.onAnyEvent,
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
  final HeliumPaymentProcessor? paymentProcessor;

  PurchaseSucceededEvent({
    required this.productId,
    required this.triggerName,
    required this.paywallName,
    required this.isSecondTry,
    this.paymentProcessor,
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

  /// Returns `_data[key]` if it is of type [T], otherwise `null`. Guards
  /// against native sending an unexpected value type for a given key.
  T? _get<T>(String key) {
    final v = _data[key];
    return v is T ? v : null;
  }

  // Type-safe getters
  Map<String, dynamic> get rawData => _data;
  String get type => _get<String>('type') ?? '';
  String? get triggerName => _get<String>('triggerName');
  String? get paywallName => _get<String>('paywallName');
  String? get productId => _get<String>('productId');
  String? get buttonName => _get<String>('buttonName');
  String? get configId => _get<String>('configId');
  String? get impressionId => _get<String>('impressionId');
  int? get responseTimeMs => _get<int>('responseTimeMs');
  int? get configDownloadTimeMs => _get<int>('configDownloadTimeMs');
  int? get fontsDownloadTimeTakenMS => _get<int>('fontsDownloadTimeTakenMS');
  int? get bundleDownloadTimeMS => _get<int>('bundleDownloadTimeMS');
  String? get canonicalJoinTransactionId => _get<String>('canonicalJoinTransactionId');
  HeliumPaymentProcessor? get paymentProcessor =>
      HeliumPaymentProcessor.fromValue(_get<String>('paymentProcessor'));
  bool? get dismissAll => _get<bool>('dismissAll');
  bool? get isSecondTry => _get<bool>('isSecondTry');
  String? get error => _get<String>('error');
  String? get paywallUnavailableReason => _get<String>('paywallUnavailableReason');
  String? get customPaywallActionName => _get<String>('actionName');
  Map<String, dynamic>? get customPaywallActionParams => getSafeData(_data['params']);
  /// Unix timestamp in seconds
  int? get timestamp => _get<int>('timestamp');

  // Deprecated getters for backwards compatibility
  /// @deprecated Use `paywallName` instead.
  String? get paywallTemplateName => _get<String>('paywallTemplateName');
  /// @deprecated Use `productId` instead.
  String? get productKey => _get<String>('productKey');
  /// @deprecated Use `buttonName` instead.
  String? get ctaName => _get<String>('ctaName');
  /// @deprecated Use `error` instead.
  String? get errorDescription => _get<String>('errorDescription');
}
