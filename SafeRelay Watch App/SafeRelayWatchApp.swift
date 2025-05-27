import SwiftUI
import WatchConnectivity

@main
struct SafeRelayWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var messages: [SecureMessage] = []
    @Published var isConnected = false
    @Published var lastSyncDate: Date?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let messageData = message["message"] as? Data,
               let decodedMessage = try? JSONDecoder().decode(SecureMessage.self, from: messageData) {
                self.messages.append(decodedMessage)
                self.lastSyncDate = Date()
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #endif
} 