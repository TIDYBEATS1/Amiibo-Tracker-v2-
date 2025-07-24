import SwiftUI
import UserNotifications
import Firebase

@main
struct AmiiboTrackerApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var service = AmiiboService()
    @StateObject private var authManager: LocalAuthManager

    private let notificationDelegate = NotificationDelegate()

    init() {
        FirebaseApp.configure()
        
        // Initialize services
        let service = AmiiboService()
        _service = StateObject(wrappedValue: service)
        _authManager = StateObject(wrappedValue: LocalAuthManager(service: service))
        
        // Notification setup
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
        
        // Activate WatchConnectivity session (iOS only)
        #if os(iOS)
        
        // Optionally save current owned Amiibos to shared defaults
        let ownedAmiibos = service.allAmiibos.filter { service.ownedAmiiboIDs.contains($0.id) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(service)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    // scheduleTestNotification() // Uncomment to test notifications
                }
                .task {
                    await service.fetchAmiibos(force: false)
                }
        }
    }

    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from AmiiboTracker."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled")
            }
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
