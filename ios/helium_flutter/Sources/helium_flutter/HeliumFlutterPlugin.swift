import Flutter
import UIKit
import Helium
import SwiftUI
import Foundation


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

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HeliumFlutterPlugin()
        instance.channel = FlutterMethodChannel(name: "helium_flutter", binaryMessenger: registrar.messenger())
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
        let factory = FLNativeViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "upsellViewForTrigger")
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

                initializeHelium(
                    apiKey: apiKey,
                    customAPIEndpoint: customAPIEndpoint,
                    customUserId: customUserId,
                    customUserTraits: customUserTraits,
                    revenueCatAppUserId: revenueCatAppUserId,
                    fallbackAssetPath: fallbackAssetPath,
                    paywallLoadingConfig: paywallLoadingConfig,
                    useDefaultDelegate: useDefaultDelegate
                )
                result("Initialization started!")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
            }
        case "getDownloadStatus":
            result(getDownloadStatus())
        case "presentUpsell":
            if let args = call.arguments as? [String: Any] {
                let trigger = args["trigger"] as? String ?? ""
                let customPaywallTraits = args["customPaywallTraits"] as? [String: Any]
                presentUpsell(trigger: trigger, customPaywallTraits: customPaywallTraits)
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
                let userTraitsMap = args["traits"] as? [String: Any] ?? [:]
                let traits = HeliumUserTraits(userTraitsMap)
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeHelium(
        apiKey: String, customAPIEndpoint: String?,
        customUserId: String?, customUserTraits: HeliumUserTraits?,
        revenueCatAppUserId: String?, fallbackAssetPath: String?,
        paywallLoadingConfig: [String: Any]?,
        useDefaultDelegate: Bool
    ) {
        Task {
            let delegate: HeliumPaywallDelegate
            if useDefaultDelegate {
                delegate = DefaultPurchaseDelegate(methodChannel: channel)
            } else {
                delegate = DemoHeliumPaywallDelegate(methodChannel: channel)
            }

            var fallbackBundleURL: URL? = nil

            // Get file from Flutter assets
            if let assetPath = fallbackAssetPath,
               let key = registrar?.lookupKey(forAsset: assetPath),
               let path = Bundle.main.path(forResource: key, ofType: nil) {
                fallbackBundleURL = URL(fileURLWithPath: path)
            }

            // Parse loading configuration
            let useLoadingState = paywallLoadingConfig?["useLoadingState"] as? Bool ?? true
            let loadingBudget = paywallLoadingConfig?["loadingBudget"] as? TimeInterval ?? 2.0

            var perTriggerLoadingConfig: [String: TriggerLoadingConfig]? = nil
            if let perTriggerDict = paywallLoadingConfig?["perTriggerLoadingConfig"] as? [String: [String: Any]] {
                var triggerConfigs: [String: TriggerLoadingConfig] = [:]
                for (trigger, config) in perTriggerDict {
                    triggerConfigs[trigger] = TriggerLoadingConfig(
                        useLoadingState: config["useLoadingState"] as? Bool,
                        loadingBudget: config["loadingBudget"] as? TimeInterval
                    )
                }
                perTriggerLoadingConfig = triggerConfigs
            }

            await Helium.shared.initialize(
                apiKey: apiKey,
                heliumPaywallDelegate: delegate,
                fallbackConfig: HeliumFallbackConfig.withMultipleFallbacks(
                    // As a workaround for required fallback check in iOS, supply empty fallbackPerTrigger
                    // since currently iOS requires some type of fallback but RN does not.
                    fallbackPerTrigger: [:],
                    fallbackBundle: fallbackBundleURL,
                    useLoadingState: useLoadingState,
                    loadingBudget: loadingBudget,
                    perTriggerLoadingConfig: perTriggerLoadingConfig
                ),
                customUserId: customUserId,
                customAPIEndpoint: customAPIEndpoint,
                customUserTraits: customUserTraits,
                revenueCatAppUserId: revenueCatAppUserId
            )
        }
    }

    public func presentUpsell(trigger: String, customPaywallTraits: [String: Any]? = nil) {
        let convertedTraits = convertMarkersToBooleans(customPaywallTraits)
        Helium.shared.presentUpsell(
            trigger: trigger,
            eventHandlers: PaywallEventHandlers.withHandlers(
                onOpen: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                },
                onClose: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                },
                onDismissed: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                },
                onPurchaseSucceeded: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                },
                onOpenFailed: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                },
                onCustomPaywallAction: { [weak self] event in
                    self?.channel.invokeMethod("onPaywallEventHandler", arguments: event.toDictionary())
                }
            ),
            customPaywallTraits: convertedTraits
        )
    }

    public func hideUpsell() -> Bool {
        Helium.shared.hideUpsell()
    }

    public func getDownloadStatus() -> String {
        return Helium.shared.getDownloadStatus().rawValue
    }

    public func getHeliumUserId() -> String? {
        return Helium.shared.getHeliumUserId()
    }

    public func paywallsLoaded() -> Bool {
        return Helium.shared.paywallsLoaded()
    }

    public func overrideUserId(newUserId: String, traits: HeliumUserTraits? = nil) {
        Helium.shared.overrideUserId(newUserId: newUserId, traits: traits)
    }

    private func fallbackOpenOrCloseEvent(trigger: String?, isOpen: Bool, viewType: String?, paywallUnavailableReason: String?) {
        let fallbackReason = paywallUnavailableReason != nil ? PaywallUnavailableReason(rawValue: paywallUnavailableReason!) : nil
        HeliumPaywallDelegateWrapper.shared.onFallbackOpenCloseEvent(trigger: trigger, isOpen: isOpen, viewType: viewType, fallbackReason: fallbackReason)
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

    private func canPresentUpsell(trigger: String) -> [String: Any] {
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
        return await Helium.shared.hasAnyActiveSubscription()
    }

    private func hasAnyEntitlement() async -> Bool {
        return await Helium.shared.hasAnyEntitlement()
    }

    private func getExperimentInfoForTrigger(trigger: String) -> [String: Any?]? {
        guard let experimentInfo = Helium.shared.getExperimentInfoForTrigger(trigger) else {
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
        Helium.restorePurchaseConfig.disableRestoreFailedDialog()
    }

    private func setCustomRestoreFailedStrings(
        customTitle: String?,
        customMessage: String?,
        customCloseButtonText: String?
    ) {
        Helium.restorePurchaseConfig.setCustomRestoreFailedStrings(
            customTitle: customTitle,
            customMessage: customMessage,
            customCloseButtonText: customCloseButtonText
        )
    }

    private func resetHelium() {
        Helium.resetHelium()
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

class DemoHeliumPaywallDelegate: HeliumPaywallDelegate {
    let _methodChannel: FlutterMethodChannel

    init(methodChannel: FlutterMethodChannel) {
        _methodChannel = methodChannel
    }

    // Required: Make a purchase
    func makePurchase(productId: String) async -> HeliumPaywallTransactionStatus {
        await withCheckedContinuation { continuation in
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
        DispatchQueue.main.async {
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
        DispatchQueue.main.async {
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

