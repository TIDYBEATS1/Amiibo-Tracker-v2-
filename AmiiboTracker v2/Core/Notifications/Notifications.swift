import Foundation
import UserNotifications

let notificationDelegate = NotificationDelegate()

func setupNotifications() {
    let center = UNUserNotificationCenter.current()
    center.delegate = notificationDelegate

    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if let error = error {
            print("Notification permission error: \(error.localizedDescription)")
        } else {
            print("Permission granted: \(granted)")
            if granted {
                scheduleNotification()
            }
        }
    }
}

func scheduleNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Hello!"
    content.body = "This is a test notification."
    content.sound = .default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
    
    let request = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: trigger)
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error.localizedDescription)")
        } else {
            print("Notification scheduled!")
        }
    }
}
