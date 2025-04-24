import Flutter
import UIKit
import Helium
import SwiftUI
import Foundation

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
          let customUserId = args["customUserId"] as? String ?? ""
          let customAPIEndpoint = args["customAPIEndpoint"] as? String ?? ""
          let userTraitsMap = args["customUserTraits"] as? [String: Any] ?? [:]
          let customUserTraits = HeliumUserTraits(userTraitsMap)
          
          Task {
            await initializeHelium(
              apiKey: apiKey,
              customUserId: customUserId,
              customAPIEndpoint: customAPIEndpoint,
              customUserTraits: customUserTraits
            )
          }
          result("Initialization started!")
      } else {
            result(FlutterError(code: "BAD_ARGS", message: "Arguments not passed correctly", details: nil))
      }
    case "getDownloadStatus":
        result(getDownloadStatus())
    case "presentUpsell":
        do{
            let trigger = call.arguments as? String ?? ""
            print(trigger)
            presentUpsell(trigger: trigger)
            result("Upsell presented!")
        }
        catch let error{
            result(FlutterError(code: "NATIVE_CRASH", message: error.localizedDescription, details: nil))
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
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeHelium(apiKey: String, customUserId: String, customAPIEndpoint: String, customUserTraits: HeliumUserTraits) {
        Task {
            let delegate = DemoHeliumPaywallDelegate(methodChannel: channel)
            let view = FallbackView()
            
            await Helium.shared.initialize(
              apiKey: apiKey,
              heliumPaywallDelegate: delegate,
              fallbackPaywall: view,
              customUserId: customUserId,
              customAPIEndpoint: customAPIEndpoint,
              customUserTraits: customUserTraits
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
}

class DemoHeliumPaywallDelegate: HeliumPaywallDelegate {
    let _methodChannel : FlutterMethodChannel;
    
    init(methodChannel : FlutterMethodChannel){
        _methodChannel = methodChannel;
    }
    
    // Required: Make a purchase
    func makePurchase(productId: String) async -> HeliumPaywallTransactionStatus {

        await withCheckedContinuation { continuation in
            _methodChannel.invokeMethod(
                "makePurchase",
                arguments: productId
            ) { result in

                let statusString = (result as? String)?.lowercased() ?? ""
                
                print("Purchase status: \(statusString)")

                let status: HeliumPaywallTransactionStatus
                switch statusString {
                case "purchased": status = .purchased
                case "cancelled": status = .cancelled
                case "restored":  status = .restored
                case "pending":   status = .pending
                default:          status = .failed(PurchaseError.unknownStatus(status: statusString))
                }
                
                print("Purchase status: \(status)")

                continuation.resume(returning: status)
            }
        }
    }
    enum PurchaseError: Error {
        case unknownStatus(status: String)
        case purchaseFailed
    }

        
        // Optional: Restore purchases (already has default, but we override)
        func restorePurchases() async -> Bool {
            // Simulate a restore operation
            DispatchQueue.main.async {
                self._methodChannel.invokeMethod(
                    "restorePurchases",
                    arguments: true
                )
            }
            return true
        }
        
        // Optional: Handle paywall event
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
        
        // Optional: Provide custom variables
        func getCustomVariableValues() -> [String: Any?] {
            return [
                "userType": "testUser",
                "campaign": "spring_launch"
            ]
        }
    }
    
    struct FallbackView: View {
        var body: some View {
            Text("Hello from DemoView!")
        }
    }
