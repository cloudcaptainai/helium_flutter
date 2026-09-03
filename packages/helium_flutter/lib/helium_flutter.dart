import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';
import 'package:helium_flutter/types/experiment_info.dart';
import 'package:helium_flutter/types/helium_config_status.dart';
import 'package:helium_flutter/types/helium_environment.dart';
import 'package:helium_flutter/types/helium_log_level.dart';
import 'package:helium_flutter/types/helium_transaction_status.dart';
import 'package:helium_flutter/types/helium_types.dart';
export './core/helium_callbacks.dart';
export './types/experiment_info.dart';
export './types/helium_log_level.dart';
export './types/helium_transaction_status.dart';
export './types/helium_types.dart';

class HeliumFlutter {
  /// Whether Helium has already been initialized (via [initialize] or [setupCore]).
  bool get isInitialized => HeliumFlutterPlatform.instance.isInitialized;

  /// Sets up core Helium configuration (delegates, callbacks, identity, etc.)
  /// without triggering native SDK initialization. Used by wrapper plugins
  /// (e.g. helium_stripe) that need to call their own specialized native
  /// initialization after core setup.
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
    return await HeliumFlutterPlatform.instance.setupCore(
      apiKey: apiKey,
      callbacks: callbacks,
      purchaseDelegate: purchaseDelegate,
      fallbackPaywall: fallbackPaywall,
      customAPIEndpoint: customAPIEndpoint,
      customUserId: customUserId,
      customUserTraits: customUserTraits,
      revenueCatAppUserId: revenueCatAppUserId,
      fallbackBundleAssetPath: fallbackBundleAssetPath,
      environment: environment,
      paywallLoadingConfig: paywallLoadingConfig,
      androidConsumableProductIds: androidConsumableProductIds,
    );
  }

  ///Initialize helium sdk at the start-up of your flutter application.
  ///
  /// [fallbackPaywall] is a Flutter widget shown as a last-resort view when a
  /// Helium paywall cannot be displayed. Prefer handling the
  /// `onPaywallUnavailable` callback on [presentUpsell] instead — the
  /// [fallbackPaywall] widget is planned for removal in the next major release.
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
    return await HeliumFlutterPlatform.instance.initialize(
      apiKey: apiKey,
      callbacks: callbacks,
      purchaseDelegate: purchaseDelegate,
      fallbackPaywall: fallbackPaywall,
      customAPIEndpoint: customAPIEndpoint,
      customUserId: customUserId,
      customUserTraits: customUserTraits,
      revenueCatAppUserId: revenueCatAppUserId,
      fallbackBundleAssetPath: fallbackBundleAssetPath,
      environment: environment,
      paywallLoadingConfig: paywallLoadingConfig,
      androidConsumableProductIds: androidConsumableProductIds,
    );
  }

  ///Gets helium user id
  Future<String?> getHeliumUserId() =>
      HeliumFlutterPlatform.instance.getHeliumUserId();

  ///Hide currently visible Helium paywall.
  Future<bool> hideUpsell() => HeliumFlutterPlatform.instance.hideUpsell();

  ///Hide all Helium paywalls.
  Future<bool> hideAllUpsells() =>
      HeliumFlutterPlatform.instance.hideAllUpsells();

  ///Overrides user id to given [newUserId]
  Future<String?> overrideUserId({
    required String newUserId,
    Map<String, dynamic>? traits,
  }) =>
      HeliumFlutterPlatform.instance.overrideUserId(
        newUserId: newUserId,
        traits: traits,
      );

  /// Clears the custom user ID previously set via [overrideUserId], reverting
  /// to Helium's anonymous user ID. Use when a user signs out.
  ///
  /// Note: [resetHelium] does not clear the custom user ID.
  Future<void> clearCustomUserId() =>
      HeliumFlutterPlatform.instance.clearCustomUserId();

  ///Returns true if Helium paywalls are loaded.
  Future<bool> paywallsLoaded() =>
      HeliumFlutterPlatform.instance.paywallsLoaded();

  static const EventChannel _statusChannel =
      EventChannel("com.tryhelium.paywall/download_status");

  ///Download status of paywall
  static Stream<HeliumConfigStatus> get downloadStatus {
    return _statusChannel.receiveBroadcastStream().map((event) {
      return HeliumConfigStatus.create(event as String?);
    });
  }

  /// Presents a full-screen paywall for [trigger].
  ///
  /// You must have a trigger and workflow configured in the Helium dashboard
  /// (https://app.tryhelium.com/workflows) in order to show a paywall.
  ///
  /// [eventHandlers] receive this presentation's paywall lifecycle events.
  /// [customPaywallTraits] are custom traits sent to the paywall; user traits
  /// are automatically included, as is "trigger", and on duplicate keys the
  /// value from [customPaywallTraits] wins.
  ///
  /// [dontShowIfAlreadyEntitled], when true, skips the paywall if the user
  /// already has an active entitlement for a product on it: [onEntitled] is
  /// called (or [onPaywallSkip] when [onEntitled] is not provided) and a
  /// `paywallSkipped` event is fired. Defaults to false, which is right for
  /// most paywalls: user-initiated paywalls (e.g. "Upgrade to Premium") and
  /// onboarding paywalls should always show, and entitled users can still use
  /// "Restore Purchases". Enable it only where a paying user must never see a
  /// paywall, such as one presented automatically on app open. If your app
  /// already tracks entitlement, keep it false and use your existing
  /// entitlement logic instead. See
  /// https://docs.tryhelium.com/sdk/quickstart-flutter#checking-subscription-status-%26-entitlements
  ///
  /// [onEntitled] is called when the user becomes entitled to a product on the
  /// paywall — on purchase success or restore. If [dontShowIfAlreadyEntitled]
  /// is true, it is also called instead of showing the paywall when the user
  /// already owns a product on it.
  ///
  /// [onPaywallSkip] is called when the paywall is intentionally not shown for
  /// [trigger] — a targeting holdout configured in your workflow
  /// (`skipReason` = [PaywallSkippedReason.targetingHoldout]), or, when
  /// [dontShowIfAlreadyEntitled] is true, an already-entitled user
  /// (`skipReason` = [PaywallSkippedReason.alreadyEntitled]). For
  /// already-entitled skips [onEntitled] takes precedence: [onPaywallSkip] is
  /// only called for that case when [onEntitled] is not provided. Not called
  /// for errors — see [onPaywallUnavailable].
  ///
  /// [onPaywallUnavailable] is called when the Helium paywall for [trigger]
  /// cannot be shown — neither the configured paywall nor a Helium fallback
  /// paywall displayed. Uncommon, but best practice to handle.
  ///
  /// This is independent of the Flutter [fallbackPaywall] view: if you supplied
  /// one to [initialize] it is still shown as a last resort, but this callback
  /// is still called so you can react to the Helium paywall being unavailable.
  /// See https://docs.tryhelium.com/guides/fallback-bundle
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    bool? dontShowIfAlreadyEntitled,
    void Function()? onEntitled,
    void Function(PaywallSkippedEvent event)? onPaywallSkip,
    void Function()? onPaywallUnavailable,
  }) =>
      HeliumFlutterPlatform.instance.presentUpsell(
        context: context,
        trigger: trigger,
        eventHandlers: eventHandlers,
        customPaywallTraits: customPaywallTraits,
        dontShowIfAlreadyEntitled: dontShowIfAlreadyEntitled,
        onEntitled: onEntitled,
        onPaywallSkip: onPaywallSkip,
        onPaywallUnavailable: onPaywallUnavailable,
      );

  Future<PaywallInfo?> getPaywallInfo(String trigger) =>
      HeliumFlutterPlatform.instance.getPaywallInfo(trigger);

  Future<bool> handleDeepLink(String uri) =>
      HeliumFlutterPlatform.instance.handleDeepLink(uri);

  /// Returns an embedded paywall widget for [trigger].
  ///
  /// [customPaywallTraits] are forwarded to the native paywall when the
  /// widget is first built. Later updates to the map are ignored — recreate
  /// the widget with a different `key` if you need fresh traits.
  ///
  /// [paywallNotShownReplacement] is rendered in place of the paywall when it cannot
  /// be shown (e.g. paywall not downloaded, skipped due to targeting).
  Widget getUpsellWidget({
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    required Widget paywallNotShownReplacement,
  }) =>
      HeliumFlutterPlatform.instance.getUpsellWidget(
        trigger: trigger,
        eventHandlers: eventHandlers,
        customPaywallTraits: customPaywallTraits,
        paywallNotShownReplacement: paywallNotShownReplacement,
      );

  /// Checks if the user has any active subscription (including non-renewable)
  Future<bool> hasAnyActiveSubscription() =>
      HeliumFlutterPlatform.instance.hasAnyActiveSubscription();

  /// Checks if the user has any entitlement
  Future<bool> hasAnyEntitlement() =>
      HeliumFlutterPlatform.instance.hasAnyEntitlement();

  /// Checks if the user has an active entitlement for any product attached to the paywall that will show for provided trigger.
  /// - Parameter trigger: Trigger that would be used to show the paywall.
  /// - Returns: `true` if the user has bought one of the products on the paywall. `false` if not. Returns `null` if not known (i.e. the paywall is not downloaded yet).
  Future<bool?> hasEntitlementForPaywall(String trigger) =>
      HeliumFlutterPlatform.instance.hasEntitlementForPaywall(trigger);

  /// Get experiment allocation info for a specific trigger
  ///
  /// - Parameter trigger: The trigger name to get experiment info for
  /// - Returns: ExperimentInfo if the trigger has experiment data, nil otherwise
  Future<ExperimentInfo?> getExperimentInfoForTrigger(String trigger) =>
      HeliumFlutterPlatform.instance.getExperimentInfoForTrigger(trigger);

  /// Disable the default dialog that Helium will display if a "Restore Purchases" action is not successful.
  /// You can handle this yourself if desired by listening for the PurchaseRestoreFailedEvent.
  void disableRestoreFailedDialog() =>
      HeliumFlutterPlatform.instance.disableRestoreFailedDialog();

  /// Set custom strings to show in the dialog that Helium will display if a "Restore Purchases" action is not successful.
  /// Note that these strings will not be localized by Helium for you.
  void setCustomRestoreFailedStrings({
    String? customTitle,
    String? customMessage,
    String? customCloseButtonText,
  }) =>
      HeliumFlutterPlatform.instance.setCustomRestoreFailedStrings(
        customTitle: customTitle,
        customMessage: customMessage,
        customCloseButtonText: customCloseButtonText,
      );

  /// Reset Helium entirely so you can call initialize again. Only for advanced use cases.
  Future<void> resetHelium({
    bool clearUserTraits = true,
    bool clearExperimentAllocations = false,
  }) =>
      HeliumFlutterPlatform.instance.resetHelium(
        clearUserTraits: clearUserTraits,
        clearExperimentAllocations: clearExperimentAllocations,
      );

  /// Sets light/dark mode override for Helium paywalls.
  /// - Parameter mode: The desired appearance mode (.light, .dark, or .system)
  /// - Note: .system respects the device's current appearance setting (default)
  void setLightDarkModeOverride(HeliumLightDarkMode mode) =>
      HeliumFlutterPlatform.instance.setLightDarkModeOverride(mode);

  /// Set RevenueCat App User ID to improve Helium revenue attribution.
  /// - Parameter rcAppUserId: RevenueCat App User ID (e.g. await Purchases.appUserID)
  void setRevenueCatAppUserId(String rcAppUserId) =>
      HeliumFlutterPlatform.instance.setRevenueCatAppUserId(rcAppUserId);

  /// An optional anonymous ID from your third-party analytics provider, sent
  /// alongside every Helium analytics event so you can correlate Helium data
  /// with your own analytics before you have set a custom user ID. Pass `null`
  /// to clear.
  ///
  /// - Amplitude: pass device ID
  /// - Mixpanel: pass anonymous ID
  /// - PostHog: pass anonymous ID
  /// - Statsig: pass stable ID
  ///
  /// Set this before calling [initialize] for best results — `await` this
  /// call to guarantee the ID is recorded before [initialize] fires. Can also
  /// be updated after initialization.
  Future<void> setThirdPartyAnalyticsAnonymousId(String? anonymousId) =>
      HeliumFlutterPlatform.instance
          .setThirdPartyAnalyticsAnonymousId(anonymousId);

  /// Set consumable product IDs for Android.
  /// These IDs will be used to identify consumable products in the Play Store
  /// and this is only respected if no custom purchaseDelegate is supplied.
  /// This is only relevant on Android and is a no-op on other platforms.
  void setAndroidConsumableProductIds(Set<String> productIds) =>
      HeliumFlutterPlatform.instance
          .setAndroidConsumableProductIds(productIds);

  /// Enables External Web Checkout Flow for any Paddle or Stripe products in
  /// your paywalls. If not enabled, paywalls with Paddle/Stripe products will
  /// not show and your fallback paywall (if provided) will show instead.
  ///
  /// You must provide a redirect URL so Helium knows where to send the user
  /// back after checkout, whether it succeeded, was cancelled, or failed. If a
  /// user returns to the app manually without the redirect URL, then the SDK
  /// will look at the latest entitlement state to determine if a purchase was
  /// made.
  ///
  /// Register the URL as a deep link (custom scheme or universal link) and
  /// forward it to [handleURL] from your URL handler.
  ///
  /// Call this before [initialize] for best results, and `await` it to
  /// guarantee the configuration is applied before [initialize] runs on the
  /// native side.
  ///
  /// - [redirectURL]: The URL checkout redirects back to when the user is
  ///   done.
  /// - [paymentProcessors]: Which processors to enable. Paddle, Stripe, or
  ///   both. Pass `{HeliumWebCheckoutProcessor.paddle}` or
  ///   `{HeliumWebCheckoutProcessor.stripe}` if your app only uses one, to
  ///   skip the unused processor's entitlement network calls. Must not be
  ///   an empty set.
  ///
  /// Currently only supported on iOS; a no-op on Android. Errors are logged
  /// internally and never thrown to the caller.
  Future<void> enableExternalWebCheckout({
    String? redirectURL,
    @Deprecated(
      'Use enableExternalWebCheckout with redirectURL instead. A single redirect '
      'URL covers success, cancel, and payment failure.',
    )
    String? successURL,
    @Deprecated(
      'Use enableExternalWebCheckout with redirectURL instead. A single redirect '
      'URL covers success, cancel, and payment failure.',
    )
    String? cancelURL,
    required Set<HeliumWebCheckoutProcessor> paymentProcessors,
  }) async {
    try {
      if (redirectURL != null) {
        await HeliumFlutterPlatform.instance.enableExternalWebCheckout(
          redirectURL: redirectURL,
          paymentProcessors: paymentProcessors,
        );
        return;
      }
      if (successURL != null && cancelURL != null) {
        await HeliumFlutterPlatform.instance
            .enableExternalWebCheckoutSuccessAndCancel(
              successURL: successURL,
              cancelURL: cancelURL,
              paymentProcessors: paymentProcessors,
            );
        return;
      }
      log(
        '[Helium] enableExternalWebCheckout: provide redirectURL '
        '(or successURL + cancelURL).',
      );
    } catch (e) {
      log('[Helium] Failed to enable External Web Checkout: $e');
    }
  }

  /// Disables External Web Checkout Flow. Paywalls with Paddle or Stripe
  /// products will not show; your fallback paywall (if provided) will show
  /// instead.
  ///
  /// Note: if you have existing Paddle/Stripe customers, Helium will attempt
  /// to continue respecting their entitlements but is not guaranteed to do so.
  ///
  /// Currently only supported on iOS; a no-op on Android. Errors are logged
  /// internally and never thrown to the caller.
  Future<void> disableExternalWebCheckout() =>
      HeliumFlutterPlatform.instance.disableExternalWebCheckout();

  /// Allows Web Checkout paywalls (Paddle/Stripe) to show even when no custom
  /// user ID has been set via [overrideUserId].
  ///
  /// By default, paywalls with Paddle or Stripe products will not show if no
  /// user ID is set, and your fallback paywall (if provided) will show
  /// instead. Set [allow] to `true` for purchase-before-signup flows — once
  /// [overrideUserId] is called later, Helium will automatically link the
  /// Paddle/Stripe customer to that user ID.
  ///
  /// **Warning:** Use with caution. If the user purchases via web checkout
  /// and your app never sets a user ID (or they uninstall before you do), the
  /// purchase may be unrecoverable for that user. Only enable this if your
  /// app has a clear path for the user to set [overrideUserId] post-purchase.
  ///
  /// Defaults to `false` on the native side. Currently only supported on iOS;
  /// a no-op on Android. Errors are logged internally and never thrown to the
  /// caller.
  Future<void> setAllowWebCheckoutWithoutUserId(bool allow) =>
      HeliumFlutterPlatform.instance.setAllowWebCheckoutWithoutUserId(allow);

  /// Returns `true` if the user has any active Stripe entitlement.
  /// Currently only supported on iOS; returns `false` on Android.
  Future<bool> hasActiveStripeEntitlement() =>
      HeliumFlutterPlatform.instance.hasActiveStripeEntitlement();

  /// Returns `true` if the user has any active Paddle entitlement.
  /// Currently only supported on iOS; returns `false` on Android.
  Future<bool> hasActivePaddleEntitlement() =>
      HeliumFlutterPlatform.instance.hasActivePaddleEntitlement();

  /// Creates a Stripe customer portal session and returns the portal URL.
  /// The host app can open this URL in a browser or in-app webview to let the
  /// user manage their subscriptions, payment methods, and invoices.
  ///
  /// - [returnUrl]: The URL Stripe redirects to after the user finishes in
  ///   the portal.
  ///
  /// Currently only supported on iOS; returns `null` on Android.
  Future<String?> createStripePortalSession({required String returnUrl}) =>
      HeliumFlutterPlatform.instance
          .createStripePortalSession(returnUrl: returnUrl);

  /// Creates a Paddle Customer Portal session for the current user and
  /// returns the portal URL. The host app can open this URL in a browser or
  /// in-app webview to let the user manage their subscriptions.
  ///
  /// Returns `null` if the session could not be created (e.g. the user has
  /// no Paddle customer ID yet, or the request failed). Currently only
  /// supported on iOS; returns `null` on Android.
  @Deprecated('Use getPaddleCustomerId() and pass the ID to your server to '
      'generate a Paddle customer portal session instead.')
  Future<String?> createPaddlePortalSession() =>
      // ignore: deprecated_member_use_from_same_package
      HeliumFlutterPlatform.instance.createPaddlePortalSession();

  /// Returns the Paddle customer ID for the current user, if one exists.
  ///
  /// Pass this ID to your server to generate a Paddle customer portal session,
  /// allowing the user to manage their subscriptions.
  ///
  /// Returns `null` if none has been assigned. Currently only supported on
  /// iOS; returns `null` on Android.
  Future<String?> getPaddleCustomerId() =>
      HeliumFlutterPlatform.instance.getPaddleCustomerId();

  /// Resets Stripe entitlements and clears the user ID. Call this to
  /// effectively "log out" a Stripe user if your app supports multiple Stripe
  /// users on the same device.
  ///
  /// Currently only supported on iOS; a no-op on Android.
  Future<void> resetStripeEntitlements() =>
      HeliumFlutterPlatform.instance.resetStripeEntitlements();

  /// Resets Paddle entitlements and clears the user ID. Call this to
  /// effectively "log out" a Paddle user if your app can support multiple
  /// Paddle users on the same device.
  ///
  /// Note: this also clears the custom user ID.
  /// Currently only supported on iOS; a no-op on Android.
  Future<void> resetPaddleEntitlements() =>
      HeliumFlutterPlatform.instance.resetPaddleEntitlements();

  /// Sets the log level for Helium logs.
  ///
  /// Safe to call before or after [initialize]; the level is
  /// preserved across re-initializations.
  ///
  /// If never called, default level is:
  /// - Debug builds: [HeliumLogLevel.info]
  /// - Release builds: [HeliumLogLevel.error]
  void setLogLevel(HeliumLogLevel level) =>
      HeliumFlutterPlatform.instance.setLogLevel(level);

  /// Forward an incoming URL to Helium so it can react to the External Web
  /// Checkout redirect without waiting for the app to foreground.
  ///
  /// Safe to call with unrelated URLs — returns `null` if external web
  /// checkout is disabled or the URL does not match the redirect URL
  /// configured via [enableExternalWebCheckout].
  ///
  /// Call this from your app's deep link handler (e.g. the callback of a
  /// package like `app_links` or `uni_links`).
  ///
  /// Returns the matched [HeliumCheckoutRedirectType] when the URL is a
  /// Helium checkout redirect and is being processed; otherwise `null`.
  /// Currently only supported on iOS; always returns `null` on Android.
  Future<HeliumCheckoutRedirectType?> handleURL(String url) =>
      HeliumFlutterPlatform.instance.handleURL(url);

  /// Controls whether the triple-tap paywall previews gesture is enabled in
  /// dev builds (DEBUG / TestFlight on iOS, debug builds on Android).
  ///
  /// Defaults to `true`.
  void setPaywallPreviewsEnabledInDevBuilds(bool enabled) =>
      HeliumFlutterPlatform.instance
          .setPaywallPreviewsEnabledInDevBuilds(enabled);

  /// Overrides for automated testing (UI tests, CI) where StoreKit / Play
  /// Billing configuration is awkward.
  ///
  /// Gate these calls behind a build-env flag so they never run in production
  /// builds. The native SDK also ignores test handlers when it detects a
  /// production environment, but do not rely on that safety net.
  HeliumTesting get testing => const HeliumTesting();
}

/// Test-only overrides for stubbing purchase, restore, and intro-offer
/// eligibility flows. Access via [HeliumFlutter.testing].
class HeliumTesting {
  const HeliumTesting();

  /// Stubs purchase attempts to return [result] instead of running the real
  /// StoreKit / Play Billing flow. Applies to every product ID.
  void setPurchaseResult(HeliumTransactionStatus result) =>
      HeliumFlutterPlatform.instance.setTestPurchaseResult(result);

  /// Stubs restore attempts to return [success] instead of running the real
  /// restore flow.
  void setRestoreResult(bool success) =>
      HeliumFlutterPlatform.instance.setTestRestoreResult(success);

  /// Overrides the intro-offer eligibility check for every product. Useful
  /// for testing the "no trial offer" UI branch.
  ///
  /// Eligibility is read during config fetch and cached, so call this before
  /// [HeliumFlutter.initialize] for the initial paywall render to reflect the
  /// override.
  void setIntroOfferEligibility(bool eligible) =>
      HeliumFlutterPlatform.instance.setTestIntroOfferEligibility(eligible);

  /// Clears all configured test handlers. The native SDK falls back to the
  /// real purchase/restore flows.
  void reset() => HeliumFlutterPlatform.instance.resetTesting();
}
