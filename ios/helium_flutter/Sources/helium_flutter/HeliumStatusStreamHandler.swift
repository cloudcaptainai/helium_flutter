import Flutter
import UIKit
import Helium

class HeliumStatusStreamHandler: NSObject, FlutterStreamHandler {
    
    private var timer: Timer?
    private var eventSink: FlutterEventSink?
    private var lastKnownStatus: HeliumFetchedConfigStatus?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // 1. Send the immediate value right now so UI updates instantly
        checkStatus()
        
        // 2. Start a timer to poll for changes (every 0.5 seconds)
        // We use a timer because the iOS SDK doesn't notify us of changes
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopTimer()
        self.eventSink = nil
        self.lastKnownStatus = nil
        return nil
    }
    
    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    private func checkStatus() {
        guard let sink = self.eventSink else { return }
        
        // Fetch current status from SDK
        let currentStatus = Helium.shared.getDownloadStatus()
        
        // Only emit if the status has changed
        if currentStatus != lastKnownStatus {
            lastKnownStatus = currentStatus
            
            let statusString = mapStatusToString(currentStatus)
            sink(statusString)
            
            // OPTIMIZATION:
            // If the status is a "Terminal" state (Success or Failure), 
            // we can stop the timer to save CPU. The config won't change again in this session.
            if currentStatus == .downloadSuccess || currentStatus == .downloadFailure {
                stopTimer()
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
