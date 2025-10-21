import Flutter
import UIKit
import Helium
import SwiftUI

/// Helper function to post paywall events via NotificationCenter
private func postPaywallEvent(_ event: any HeliumEvent) {
    NotificationCenter.default.post(
        name: .paywallEventHandlerDispatch,
        object: nil,
        userInfo: ["event": event.toDictionary()]
    )
}

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args)
    }

    // Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    let arguments: Any?
    private lazy var _view: UIView = {
        let trigger: String = (arguments as? [String: Any])?["trigger"] as? String ?? ""
        return upsellViewForTrigger(trigger: trigger)
    }()

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) {
        arguments = args
        super.init()
    }

    func view() -> UIView {
        return _view
    }

    func upsellViewForTrigger(trigger : String) -> UIView {
        let swiftUIView = Helium.shared.upsellViewForTrigger(
            trigger: trigger,
            eventHandlers: PaywallEventHandlers.withHandlers(
                onOpen: postPaywallEvent,
                onClose: postPaywallEvent,
                onDismissed: postPaywallEvent,
                onPurchaseSucceeded: postPaywallEvent,
                onOpenFailed: postPaywallEvent,
                onCustomPaywallAction: postPaywallEvent
            )
        )
        guard let swiftUIView else {
            // this should never happen because we check canPresentUpsell before creating this view
            return UITextField()
        }
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        return hostingController.view
    }
}
