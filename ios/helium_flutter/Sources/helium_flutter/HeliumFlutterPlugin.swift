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
  var channel : FlutterMethodChannel!
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HeliumFlutterPlugin()
    instance.channel = FlutterMethodChannel(name: "helium_flutter", binaryMessenger: registrar.messenger())
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
          let userTraitsMap = args["customUserTraits"] as? [String: Any]
          let customUserTraits = userTraitsMap != nil ? HeliumUserTraits(userTraitsMap!) : nil
          let revenueCatAppUserId = args["revenueCatAppUserId"] as? String

          initializeHelium(
            apiKey: apiKey,
            customAPIEndpoint: customAPIEndpoint,
            customUserId: customUserId,
            customUserTraits: customUserTraits,
            revenueCatAppUserId: revenueCatAppUserId
          )
          result("Initialization started!")
      } else {
            result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
      }
    case "getDownloadStatus":
        result(getDownloadStatus())
    case "presentUpsell":
        let trigger = call.arguments as? String ?? ""
        presentUpsell(trigger: trigger)
        result("Upsell presented!")
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
            fallbackOpenOrCloseEvent(trigger: trigger, isOpen: true, viewType: viewType)
            result("fallback open event!")
        } else {
            result("fallback open event fail")
        }
    case "fallbackCloseEvent":
        if let args = call.arguments as? [String: Any] {
            let trigger = args["trigger"] as? String
            let viewType = args["viewType"] as? String
            fallbackOpenOrCloseEvent(trigger: trigger, isOpen: false, viewType: viewType)
            result("fallback close event!")
        } else {
            result("fallback close event fail")
        }
    case "getPaywallInfo":
        let trigger = call.arguments as? String ?? ""
        let paywallInfo = getPaywallInfo(trigger: trigger)
        result(paywallInfo)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeHelium(
    apiKey: String, customAPIEndpoint: String?,
    customUserId: String?, customUserTraits: HeliumUserTraits?,
    revenueCatAppUserId: String?
  ) {
    Task {
      let delegate = DemoHeliumPaywallDelegate(methodChannel: channel)
      let view = FallbackView()

      await Helium.shared.initialize(
        apiKey: apiKey,
        heliumPaywallDelegate: delegate,
        fallbackPaywall: view,
        customUserId: customUserId,
        customAPIEndpoint: customAPIEndpoint,
        customUserTraits: customUserTraits,
        revenueCatAppUserId: revenueCatAppUserId
      )
    }
  }
    
    public func presentUpsell(trigger: String, from viewController: UIViewController? = nil) {
        Helium.shared.presentUpsell(trigger: trigger)
    }
    
    public func hideUpsell() -> Bool{
        Helium.shared.hideUpsell()
    }
    
    public func getDownloadStatus() -> String {
        return Helium.shared.getDownloadStatus().toString()
    }
    
    public func getHeliumUserId() -> String?{
        return Helium.shared.getHeliumUserId()
    }
    
    public func paywallsLoaded()-> Bool{
        return Helium.shared.paywallsLoaded()
    }
    public func overrideUserId(newUserId: String, traits: HeliumUserTraits? = nil) {
        Helium.shared.overrideUserId(newUserId: newUserId, traits: traits)
    }

    private func fallbackOpenOrCloseEvent(trigger: String?, isOpen: Bool, viewType: String?) {
        HeliumPaywallDelegateWrapper.shared.onFallbackOpenCloseEvent(trigger: trigger, isOpen: isOpen, viewType: viewType)
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

}

class DemoHeliumPaywallDelegate: HeliumPaywallDelegate {
    let _methodChannel : FlutterMethodChannel;
    
    init(methodChannel : FlutterMethodChannel){
        _methodChannel = methodChannel;
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
                        case "purchased": status = .purchased
                        case "cancelled": status = .cancelled
                        case "restored":  status = .restored
                        case "pending":   status = .pending
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

    func onHeliumPaywallEvent(event: HeliumPaywallEvent) {
        // Log or handle event
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(event)
            let json = String(data: jsonData, encoding: .utf8)
            DispatchQueue.main.async {
                self._methodChannel.invokeMethod(
                    "onPaywallEvent",
                    arguments: json
                )
            }
        } catch {
            print("Failed to encode event: \(error)")
        }
    }

    // Optional: Provide custom variables (not implemented for now)
//     func getCustomVariableValues() -> [String: Any?] {
//         return [
//             "userType": "testUser",
//             "campaign": "spring_launch"
//         ]
//     }
}

fileprivate struct FallbackView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Fallback Paywall")
                .font(.title)
                .fontWeight(.bold)

            Text("Something went wrong loading the paywall. Make sure you used the right trigger.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding()
    }
}
