import Flutter
import UIKit
import Helium

class HeliumStatusStreamHandler: NSObject, FlutterStreamHandler, HeliumEventListener {

    private var eventSink: FlutterEventSink?
    private var lastKnownStatus: HeliumFetchedConfigStatus?

    override init() {
        super.init()

        // Observe NotificationCenter events for initialization and reset
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeliumInitializing),
            name: .heliumInitializing,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeliumReset),
            name: .heliumReset,
            object: nil
        )
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        // Send the initial status immediately
        let currentStatus = Helium.shared.getDownloadStatus()
        lastKnownStatus = currentStatus
        events(mapStatusToString(currentStatus))

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        self.lastKnownStatus = nil
        return nil
    }

    @objc private func handleHeliumInitializing() {
        Helium.shared.addHeliumEventListener(self)

        // Update status to inProgress
        emitStatus(.inProgress)
    }

    @objc private func handleHeliumReset() {
        // SDK clears event listeners on reset, so we just update status
        emitStatus(.notDownloadedYet)
    }

    // HeliumEventListener protocol implementation
    func onHeliumEvent(event: HeliumEvent) {
        if event is PaywallsDownloadSuccessEvent {
            emitStatus(.downloadSuccess)
        } else if event is PaywallsDownloadErrorEvent {
            emitStatus(.downloadFailure)
        }
    }

    private func emitStatus(_ status: HeliumFetchedConfigStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let sink = eventSink else { return }

            // Only emit if the status has changed
            if status != lastKnownStatus {
                lastKnownStatus = status
                sink(mapStatusToString(status))
            }
        }
    }

    private func mapStatusToString(_ status: HeliumFetchedConfigStatus) -> String {
        switch status {
        case .notDownloadedYet:
            return "notDownloadedYet"
        case .inProgress:
            return "inProgress"
        case .downloadSuccess:
            return "downloadSuccess"
        case .downloadFailure:
            return "downloadFailure"
        @unknown default:
            return "notDownloadedYet"
        }
    }
}
