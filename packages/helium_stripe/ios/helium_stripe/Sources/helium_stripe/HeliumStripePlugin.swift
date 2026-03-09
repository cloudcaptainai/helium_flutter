import Flutter
import UIKit
import Helium
import StripeOneTapPurchase

public class HeliumStripePlugin: NSObject, FlutterPlugin {
    var channel: FlutterMethodChannel!

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HeliumStripePlugin()
        instance.channel = FlutterMethodChannel(name: "helium_stripe", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeStripe":
            if let config = call.arguments as? [String: Any] {
                initializeStripe(config: config, result: result)
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
            }
        case "setUserIdAndSyncStripeIfNeeded":
            if let userId = call.arguments as? String {
                Helium.shared.setUserIdAndSyncStripeIfNeeded(userId: userId)
                result(nil)
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "userId not provided", details: nil))
            }
        case "resetStripeEntitlements":
            let clearUserId = call.arguments as? Bool ?? false
            Helium.shared.resetStripeEntitlements(clearUserId: clearUserId)
            result(nil)
        case "createStripePortalSession":
            if let returnUrl = call.arguments as? String {
                Task {
                    do {
                        let url = try await Helium.shared.createStripePortalSession(returnUrl: returnUrl)
                        DispatchQueue.main.async { result(url.absoluteString) }
                    } catch {
                        DispatchQueue.main.async { result(FlutterError(code: "STRIPE_ERROR", message: "Failed to create Stripe portal session: \(error.localizedDescription)", details: nil)) }
                    }
                }
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "returnUrl not provided", details: nil))
            }
        case "hasActiveStripeEntitlement":
            Task {
                let hasEntitlement = await Helium.shared.hasActiveStripeEntitlement()
                DispatchQueue.main.async { result(hasEntitlement) }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeStripe(config: [String: Any], result: @escaping FlutterResult) {
        guard let apiKey = config["apiKey"] as? String,
              let stripePublishableKey = config["stripePublishableKey"] as? String,
              let merchantIdentifier = config["merchantIdentifier"] as? String,
              let merchantName = config["merchantName"] as? String,
              let managementURLString = config["managementURL"] as? String,
              let managementURL = URL(string: managementURLString) else {
            var missing: [String] = []
            if config["apiKey"] as? String == nil { missing.append("apiKey") }
            if config["stripePublishableKey"] as? String == nil { missing.append("stripePublishableKey") }
            if config["merchantIdentifier"] as? String == nil { missing.append("merchantIdentifier") }
            if config["merchantName"] as? String == nil { missing.append("merchantName") }
            if config["managementURL"] as? String == nil { missing.append("managementURL") }
            else if URL(string: config["managementURL"] as! String) == nil { missing.append("managementURL (invalid URL)") }
            result(FlutterError(
                code: "INVALID_STRIPE_CONFIG",
                message: "Missing or invalid Stripe config parameters: \(missing.joined(separator: ", "))",
                details: nil
            ))
            return
        }

        let countryCode = config["countryCode"] as? String ?? "US"
        let currencyCode = config["currencyCode"] as? String ?? "USD"

        Helium.shared.initializeWithStripeOneTap(
            apiKey: apiKey,
            stripePublishableKey: stripePublishableKey,
            backupPurchaseDelegate: Helium.config.purchaseDelegate,
            merchantIdentifier: merchantIdentifier,
            merchantName: merchantName,
            managementURL: managementURL,
            countryCode: countryCode,
            currencyCode: currencyCode
        )
        result(nil)
    }
}
