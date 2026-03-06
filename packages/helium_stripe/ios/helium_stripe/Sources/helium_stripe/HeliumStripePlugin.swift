import Flutter
import UIKit
import Helium
import StripeOneTapPurchase
@preconcurrency import StripeApplePay

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
                        result(url.absoluteString)
                    } catch {
                        result(FlutterError(code: "STRIPE_ERROR", message: "Failed to create Stripe portal session: \(error.localizedDescription)", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "returnUrl not provided", details: nil))
            }
        case "hasActiveStripeEntitlement":
            Task {
                let hasEntitlement = await Helium.shared.hasActiveStripeEntitlement()
                result(hasEntitlement)
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
            print("[HeliumStripe] Missing or invalid Stripe config, using standard initialization instead")
            Helium.shared.initialize(apiKey: config["apiKey"] as? String ?? "")
            result(nil)
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
