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
        let args = arguments as? [String: Any] ?? [:]
        let trigger = args["trigger"] as? String ?? ""
        let traitsMap = convertMarkersToBooleans(args["customPaywallTraits"] as? [String: Any])
        let customPaywallTraits = traitsMap.map { HeliumUserTraits($0) }
        return makePaywallView(trigger: trigger, customPaywallTraits: customPaywallTraits)
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

    func makePaywallView(trigger: String, customPaywallTraits: HeliumUserTraits?) -> UIView {
        let config = PaywallPresentationConfig(customPaywallTraits: customPaywallTraits)
        let paywallView = HeliumPaywall(
            trigger: trigger,
            config: config,
            eventHandlers: PaywallEventHandlers.withHandlers(
                onAnyEvent: postPaywallEvent
            )
        ) { _ in
            EmptyView()
        }
        let hostingController = UIHostingController(rootView: paywallView)
        hostingController.view.backgroundColor = .clear
        return hostingController.view
    }
}
