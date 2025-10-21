import Flutter
import UIKit
import Helium
import SwiftUI

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }

    // Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    let arguments: Any?
    private var channel: FlutterMethodChannel
    private lazy var _view: UIView = {
        let trigger: String = (arguments as? [String: Any])?["trigger"] as? String ?? ""
        return upsellViewForTrigger(trigger: trigger)
    }()

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        arguments = args
        channel = FlutterMethodChannel(name: "helium_flutter", binaryMessenger: messenger!)
        super.init()
    }

    func view() -> UIView {
        return _view
    }

    func upsellViewForTrigger(trigger : String) -> UIView {
        let swiftUIView = Helium.shared.upsellViewForTrigger(
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
            )
        )
        guard let swiftUIView else {
            // this should never happen because we check canPresentUpsell before creating this view
            return Text("")
        }
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        return hostingController.view
    }
}
