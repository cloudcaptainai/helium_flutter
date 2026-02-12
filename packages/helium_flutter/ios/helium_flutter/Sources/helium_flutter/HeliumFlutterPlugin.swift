import Flutter
import UIKit
import Helium
import SwiftUI
import Foundation

// Notification names for events
extension NSNotification.Name {
    static let paywallEventHandlerDispatch = NSNotification.Name("paywallEventHandlerDispatch")
    static let heliumInitializing = NSNotification.Name("heliumInitializing")
    static let heliumReset = NSNotification.Name("heliumReset")
}

enum PurchaseError: LocalizedError {
    case unknownStatus(status: String)
    case purchaseFailed(errorMsg: String)

    var errorDescription: String? {
        switch self {
        case let .unknownStatus(status):
            return "Purchased not successful due to unknown status - \(status)."
        case let .purchaseFailed(errorMsg):
            return errorMsg
        }
    }
}

public class HeliumFlutterPlugin: NSObject, FlutterPlugin {
    var channel: FlutterMethodChannel!
    var registrar: FlutterPluginRegistrar?
    private var statusStreamHandler: HeliumStatusStreamHandler?
    private var logListenerToken: HeliumLogListenerToken?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HeliumFlutterPlugin()
        instance.channel = FlutterMethodChannel(name: "helium_flutter", binaryMessenger: registrar.messenger())
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: instance.channel)

        // Set up NotificationCenter observer for paywall events
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.handlePaywallEventNotification(_:)),
            name: .paywallEventHandlerDispatch,
            object: nil
        )

        let factory = FLNativeViewFactory()
        registrar.register(factory, withId: "upsellViewForTrigger")

        let statusChannel = FlutterEventChannel(name: "com.tryhelium.paywall/download_status", binaryMessenger: registrar.messenger())
        let streamHandler = HeliumStatusStreamHandler()
        instance.statusStreamHandler = streamHandler
        statusChannel.setStreamHandler(streamHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if let args = call.arguments as? [String: Any] {
                let apiKey = args["apiKey"] as? String ?? ""
                let customAPIEndpoint = args["customAPIEndpoint"] as? String
                let customUserId = args["customUserId"] as? String
                let userTraitsMap = convertMarkersToBooleans(args["customUserTraits"] as? [String: Any])
                let customUserTraits = userTraitsMap != nil ? HeliumUserTraits(userTraitsMap!) : nil
                let revenueCatAppUserId = args["revenueCatAppUserId"] as? String
                let fallbackAssetPath = args["fallbackAssetPath"] as? String
                let paywallLoadingConfig = convertMarkersToBooleans(args["paywallLoadingConfig"] as? [String: Any])

                let useDefaultDelegate = args["useDefaultDelegate"] as? Bool ?? false
                let wrapperSdkVersion = args["wrapperSdkVersion"] as? String ?? "unknown"
                let delegateType = args["delegateType"] as? String

                initializeHelium(
                    apiKey: apiKey,
                    customAPIEndpoint: customAPIEndpoint,
                    customUserId: customUserId,
                    customUserTraits: customUserTraits,
                    revenueCatAppUserId: revenueCatAppUserId,
                    fallbackAssetPath: fallbackAssetPath,
                    paywallLoadingConfig: paywallLoadingConfig,
                    useDefaultDelegate: useDefaultDelegate,
                    wrapperSdkVersion: wrapperSdkVersion,
                    delegateType: delegateType
                )
                result("Initialization started!")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
            }
        case "presentUpsell":
            if let args = call.arguments as? [String: Any] {
                let trigger = args["trigger"] as? String ?? ""
                let customPaywallTraits = args["customPaywallTraits"] as? [String: Any]
                let dontShowIfAlreadyEntitled = args["dontShowIfAlreadyEntitled"] as? Bool
                presentUpsell(trigger: trigger, customPaywallTraits: customPaywallTraits, dontShowIfAlreadyEntitled: dontShowIfAlreadyEntitled)
                result("Upsell presented!")
            } else {
                result("Upsell not presented - invalid arguments")
            }
        case "hideUpsell":
            result(hideUpsell())
        case "getHeliumUserId":
            result(getHeliumUserId())
        case "paywallsLoaded":
            result(paywallsLoaded())
        case "overrideUserId":
            if let args = call.arguments as? [String: Any] {
                let newUserId = args["newUserId"] as? String ?? ""
                let userTraitsMap = convertMarkersToBooleans(args["traits"] as? [String: Any])
                let traits = userTraitsMap != nil ? HeliumUserTraits(userTraitsMap!) : nil
                overrideUserId(newUserId: newUserId, traits: traits)
                result("User id is updated!")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
            }
        case "fallbackOpenEvent":
            if let args = call.arguments as? [String: Any] {
                let trigger = args["trigger"] as? String
                let viewType = args["viewType"] as? String
                let paywallUnavailableReason = args["paywallUnavailableReason"] as? String
                fallbackOpenOrCloseEvent(trigger: trigger, isOpen: true, viewType: viewType, paywallUnavailableReason: paywallUnavailableReason)
                result("fallback open event!")
            } else {
                result("fallback open event fail")
            }
        case "fallbackCloseEvent":
            if let args = call.arguments as? [String: Any] {
                let trigger = args["trigger"] as? String
                let viewType = args["viewType"] as? String
                let paywallUnavailableReason = args["paywallUnavailableReason"] as? String
                fallbackOpenOrCloseEvent(trigger: trigger, isOpen: false, viewType: viewType, paywallUnavailableReason: paywallUnavailableReason)
                result("fallback close event!")
            } else {
                result("fallback close event fail")
            }
        case "getPaywallInfo":
            let trigger = call.arguments as? String ?? ""
            let paywallInfo = getPaywallInfo(trigger: trigger)
            result(paywallInfo)
        case "canPresentUpsell":
            let trigger = call.arguments as? String ?? ""
            result(canPresentUpsell(trigger: trigger))
        case "handleDeepLink":
            let urlString = call.arguments as? String ?? ""
            result(handleDeepLink(urlString))
        case "hasAnyActiveSubscription":
            Task {
                let hasSubscription = await hasAnyActiveSubscription()
                result(hasSubscription)
            }
        case "hasAnyEntitlement":
            Task {
                let hasEntitlement = await hasAnyEntitlement()
                result(hasEntitlement)
            }
        case "hasEntitlementForPaywall":
            let trigger = call.arguments as? String ?? ""
            Task {
                let hasEntitlement = await hasEntitlementForPaywall(trigger: trigger)
                result(hasEntitlement)
            }
        case "getExperimentInfoForTrigger":
            let trigger = call.arguments as? String ?? ""
            let experimentInfo = getExperimentInfoForTrigger(trigger: trigger)
            result(experimentInfo)
        case "disableRestoreFailedDialog":
            disableRestoreFailedDialog()
            result("Restore failed dialog disabled!")
        case "setCustomRestoreFailedStrings":
            if let args = call.arguments as? [String: Any] {
                let customTitle = args["customTitle"] as? String
                let customMessage = args["customMessage"] as? String
                let customCloseButtonText = args["customCloseButtonText"] as? String
                setCustomRestoreFailedStrings(
                    customTitle: customTitle,
                    customMessage: customMessage,
                    customCloseButtonText: customCloseButtonText
                )
                result("Custom restore failed strings set!")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
            }
        case "resetHelium":
            resetHelium()
            result("Helium reset!")
        case "setLightDarkModeOverride":
            if let modeString = call.arguments as? String {
                setLightDarkModeOverride(mode: modeString)
                result("Light/Dark mode override set!")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Mode not provided", details: nil))
            }
        case "setRevenueCatAppUserId":
            if let rcAppUserId = call.arguments as? String {
                Helium.identify.revenueCatAppUserId = rcAppUserId
                result("RevenueCat App User ID set!")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "rcAppUserId not provided", details: nil))
            }
        case "hideAllUpsells":
            Helium.shared.hideAllPaywalls()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeHelium(
        apiKey: String, customAPIEndpoint: String?,
        customUserId: String?, customUserTraits: HeliumUserTraits?,
        revenueCatAppUserId: String?, fallbackAssetPath: String?,
        paywallLoadingConfig: [String: Any]?,
        useDefaultDelegate: Bool,
        wrapperSdkVersion: String,
        delegateType: String?
    ) {
        NotificationCenter.default.post(name: .heliumInitializing, object: nil)

        // Set wrapper SDK info for analytics
        HeliumSdkConfig.shared.setWrapperSdkInfo(sdk: "flutter", version: wrapperSdkVersion)

        // Parse loading configuration
        let useLoadingState = paywallLoadingConfig?["useLoadingState"] as? Bool ?? true
        let loadingBudget = paywallLoadingConfig?["loadingBudget"] as? TimeInterval
        if !useLoadingState {
            // Setting <= 0 will disable loading state
            Helium.config.defaultLoadingBudget = -1
        } else {
            Helium.config.defaultLoadingBudget = loadingBudget ?? 7.0
        }

        // Set up delegate
        let delegate: HeliumPaywallDelegate
        if useDefaultDelegate {
            delegate = DefaultPurchaseDelegate(methodChannel: channel)
        } else {
            delegate = DemoHeliumPaywallDelegate(delegateType: delegateType, methodChannel: channel)
        }
        Helium.config.purchaseDelegate = delegate

        // Set custom API endpoint
        if let customAPIEndpoint {
            Helium.config.customAPIEndpoint = customAPIEndpoint
        }

        // Set up fallback bundle
        if let assetPath = fallbackAssetPath,
           let key = registrar?.lookupKey(forAsset: assetPath),
           let path = Bundle.main.path(forResource: key, ofType: nil) {
            Helium.config.customFallbacksURL = URL(fileURLWithPath: path)
        }

        // Set identity
        if let customUserId {
            Helium.identify.userId = customUserId
        }
        if let customUserTraits {
            Helium.identify.setUserTraits(customUserTraits)
        }
        if let revenueCatAppUserId {
            Helium.identify.revenueCatAppUserId = revenueCatAppUserId
        }

        // Set up log listener to forward native SDK logs to Flutter
        if logListenerToken == nil {
            logListenerToken = HeliumLogger.addLogListener { [weak self] event in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let eventData: [String: Any] = [
                        "level": event.level.rawValue,
                        "category": event.category.rawValue,
                        "message": event.message,
                        "metadata": event.metadata
                    ]
                    self.channel.invokeMethod("onHeliumLogEvent", arguments: eventData)
                }
            }
        }

        Helium.shared.initialize(apiKey: apiKey)
    }

    public func presentUpsell(trigger: String, customPaywallTraits: [String: Any]? = nil, dontShowIfAlreadyEntitled: Bool? = nil) {
        let convertedTraits = convertMarkersToBooleans(customPaywallTraits)
        Helium.shared.presentPaywall(
            trigger: trigger,
            config: PaywallPresentationConfig(
                customPaywallTraits: convertedTraits,
                dontShowIfAlreadyEntitled: dontShowIfAlreadyEntitled ?? false
            ),
            eventHandlers: PaywallEventHandlers.withHandlers(
                onAnyEvent: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                }
            )
        ) { _ in
            // paywallNotShownReason callback - nothing for now
        }
    }

    public func hideUpsell() -> Bool {
        Helium.shared.hidePaywall()
    }

    public func getHeliumUserId() -> String? {
        return Helium.identify.userId
    }

    public func paywallsLoaded() -> Bool {
        return Helium.shared.paywallsLoaded()
    }

    public func overrideUserId(newUserId: String, traits: HeliumUserTraits? = nil) {
        Helium.identify.userId = newUserId
        if let traits {
            Helium.identify.setUserTraits(traits)
        }
    }

    private func fallbackOpenOrCloseEvent(trigger: String?, isOpen: Bool, viewType: String?, paywallUnavailableReason: String?) {
        // Taking this out for now, this method is no longer exposed
        // by native SDK and paywall open fail event will fire anyways so we can use that.
        // let fallbackReason = paywallUnavailableReason != nil ? PaywallUnavailableReason(rawValue: paywallUnavailableReason!) : nil
        // HeliumPaywallDelegateWrapper.shared.onFallbackOpenCloseEvent(trigger: trigger, isOpen: isOpen, viewType: viewType, fallbackReason: fallbackReason)
    }

    private func getPaywallInfo(trigger: String) -> [String: Any?] {
        guard let paywallInfo = Helium.shared.getPaywallInfo(trigger: trigger) else {
            return [
                "errorMsg": "Invalid trigger or paywalls not ready.",
                "templateName": nil,
                "shouldShow": nil
            ]
        }

        return [
            "errorMsg": nil,
            "templateName": paywallInfo.paywallTemplateName,
            "shouldShow": paywallInfo.shouldShow
        ]
    }

    private func canPresentUpsell(trigger: String) -> [String: Any?] {
        let result = Helium.shared.canShowPaywallFor(trigger: trigger)
        return [
            "canShow": result.canShow,
            "isFallback": result.isFallback,
            "paywallUnavailableReason": result.paywallUnavailableReason?.rawValue
        ]
    }

    private func handleDeepLink(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        return Helium.shared.handleDeepLink(url)
    }

    private func hasAnyActiveSubscription() async -> Bool {
        return await Helium.entitlements.hasAnyActiveSubscription()
    }

    private func hasAnyEntitlement() async -> Bool {
        return await Helium.entitlements.hasAny()
    }

    private func hasEntitlementForPaywall(trigger: String) async -> Bool? {
        return await Helium.entitlements.hasEntitlementForPaywall(trigger: trigger)
    }

    private func getExperimentInfoForTrigger(trigger: String) -> [String: Any?]? {
        guard let experimentInfo = Helium.experiments.infoForTrigger(trigger) else {
            return nil
        }

        // Convert ExperimentInfo to dictionary using JSONEncoder
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(experimentInfo),
              let dictionary = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }

        return dictionary
    }

    private func disableRestoreFailedDialog() {
        Helium.config.restorePurchasesDialog.disableRestoreFailedDialog()
    }

    private func setCustomRestoreFailedStrings(
        customTitle: String?,
        customMessage: String?,
        customCloseButtonText: String?
    ) {
        Helium.config.restorePurchasesDialog.setCustomRestoreFailedStrings(
            customTitle: customTitle,
            customMessage: customMessage,
            customCloseButtonText: customCloseButtonText
        )
    }

    private func resetHelium() {
        // Clean up log listener
        logListenerToken?.remove()
        logListenerToken = nil

        NotificationCenter.default.post(name: .heliumReset, object: nil)
        Helium.resetHelium()
    }

    private func setLightDarkModeOverride(mode: String) {
        let heliumMode: HeliumLightDarkMode
        switch mode.lowercased() {
        case "light":
            heliumMode = .light
        case "dark":
            heliumMode = .dark
        case "system":
            heliumMode = .system
        default:
            print("[Helium] Unknown mode: \(mode), defaulting to system")
            heliumMode = .system
        }
        Helium.config.lightDarkModeOverride = heliumMode
    }

    /// Handler for paywall event notifications posted via NotificationCenter
    @objc private func handlePaywallEventNotification(_ notification: Notification) {
        guard let eventDict = notification.userInfo?["event"] as? [String: Any],
              let channel else {
            return
        }
        channel.invokeMethod("onPaywallEventHandler", arguments: eventDict)
    }

    /// Recursively converts special marker strings back to boolean values to restore
    /// type information that was preserved when passing through platform channels.
    ///
    /// Flutter's platform channels convert booleans to NSNumber (0/1), so we use
    /// special marker strings to preserve the original intent. This helper converts:
    /// - "__helium_flutter_bool_true__" -> true
    /// - "__helium_flutter_bool_false__" -> false
    /// - All other values remain unchanged
    private func convertMarkersToBooleans(_ input: [String: Any]?) -> [String: Any]? {
        guard let input = input else { return nil }

        var result: [String: Any] = [:]
        for (key, value) in input {
            result[key] = convertValueMarkersToBooleans(value)
        }
        return result
    }

    /// Helper to recursively convert marker strings in any value type
    private func convertValueMarkersToBooleans(_ value: Any) -> Any {
        if let stringValue = value as? String {
            switch stringValue {
            case "__helium_flutter_bool_true__":
                return true
            case "__helium_flutter_bool_false__":
                return false
            default:
                return stringValue
            }
        } else if let dictValue = value as? [String: Any] {
            return convertMarkersToBooleans(dictValue) ?? [:]
        } else if let arrayValue = value as? [Any] {
            return arrayValue.map { convertValueMarkersToBooleans($0) }
        }
        return value
    }
}

class DemoHeliumPaywallDelegate: HeliumPaywallDelegate, HeliumDelegateReturnsTransaction {
    private let _delegateType: String?
    public var delegateType: String { _delegateType ?? "custom" }
    let _methodChannel: FlutterMethodChannel

    // Thread-safe storage for transaction result
    private var _latestTransactionResult: HeliumTransactionIdResult?
    private let transactionResultLock = NSLock()
    var latestTransactionResult: HeliumTransactionIdResult? {
        get {
            transactionResultLock.lock()
            defer { transactionResultLock.unlock() }
            return _latestTransactionResult
        }
        set {
            transactionResultLock.lock()
            defer { transactionResultLock.unlock() }
            _latestTransactionResult = newValue
        }
    }

    init(delegateType: String?, methodChannel: FlutterMethodChannel) {
        _delegateType = delegateType
        _methodChannel = methodChannel
    }

    // HeliumDelegateReturnsTransaction protocol method
    func getLatestCompletedTransactionIdResult() -> HeliumTransactionIdResult? {
        return latestTransactionResult
    }

    // Required: Make a purchase
    func makePurchase(productId: String) async -> HeliumPaywallTransactionStatus {
        // Clear previous transaction result
        latestTransactionResult = nil

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: .failed(PurchaseError.purchaseFailed(errorMsg: "Plugin instance deallocated")))
                    return
                }

                _methodChannel.invokeMethod(
                    "makePurchase",
                    arguments: productId
                ) { result in
                    let status: HeliumPaywallTransactionStatus

                    if let resultMap = result as? [String: Any],
                       let statusString = resultMap["status"] as? String {

                        let lowercasedStatus = statusString.lowercased()
                        print("Purchase status: \(lowercasedStatus)")

                        switch lowercasedStatus {
                        case "purchased":
                            status = .purchased
                            // Store transaction IDs for HeliumDelegateReturnsTransaction
                            if let transactionId = resultMap["transactionId"] as? String,
                               let productId = resultMap["productId"] as? String {
                                self.latestTransactionResult = HeliumTransactionIdResult(
                                    productId: productId,
                                    transactionId: transactionId,
                                    originalTransactionId: resultMap["originalTransactionId"] as? String
                                )
                            }
                        case "cancelled":
                            status = .cancelled
                        case "restored":
                            status = .restored
                        case "pending":
                            status = .pending
                        case "failed":
                            let errorMsg = resultMap["error"] as? String ?? "Unknown purchase error"
                            status = .failed(PurchaseError.purchaseFailed(errorMsg: errorMsg))
                        default:
                            status = .failed(PurchaseError.unknownStatus(status: lowercasedStatus))
                        }
                    } else {
                        // Handle case where result is not in expected format
                        status = .failed(PurchaseError.purchaseFailed(errorMsg: "Invalid response format"))
                    }

                    print("Purchase status: \(status)")
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func restorePurchases() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                _methodChannel.invokeMethod(
                    "restorePurchases",
                    arguments: nil
                ) { result in
                    let success = (result as? Bool) ?? false
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func onPaywallEvent(_ event: any HeliumEvent) {
        // Log or handle event
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var eventDict = event.toDictionary()
            // Add deprecated fields for backwards compatibility
            if let paywallName = eventDict["paywallName"] {
                eventDict["paywallTemplateName"] = paywallName
            }
            if let error = eventDict["error"] {
                eventDict["errorDescription"] = error
            }
            if let productId = eventDict["productId"] {
                eventDict["productKey"] = productId
            }
            if let buttonName = eventDict["buttonName"] {
                eventDict["ctaName"] = buttonName
            }

            self._methodChannel.invokeMethod(
                "onPaywallEvent",
                arguments: eventDict
            )
        }
    }

    // Optional: Provide custom variables (not implemented for now)
    // func getCustomVariableValues() -> [String: Any?] {
    //     return [
    //         "userType": "testUser",
    //         "campaign": "spring_launch"
    //     ]
    // }
}

fileprivate class DefaultPurchaseDelegate: StoreKitDelegate {
    let _methodChannel: FlutterMethodChannel

    init(methodChannel: FlutterMethodChannel) {
        _methodChannel = methodChannel
    }

    override func onPaywallEvent(_ event: any HeliumEvent) {
        // Log or handle event
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var eventDict = event.toDictionary()
            // Add deprecated fields for backwards compatibility
            if let paywallName = eventDict["paywallName"] {
                eventDict["paywallTemplateName"] = paywallName
            }
            if let error = eventDict["error"] {
                eventDict["errorDescription"] = error
            }
            if let productId = eventDict["productId"] {
                eventDict["productKey"] = productId
            }
            if let buttonName = eventDict["buttonName"] {
                eventDict["ctaName"] = buttonName
            }

            self._methodChannel.invokeMethod(
                "onPaywallEvent",
                arguments: eventDict
            )
        }
    }
}

