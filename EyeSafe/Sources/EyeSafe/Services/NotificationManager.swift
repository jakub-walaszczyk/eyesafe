import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[EyeSafe] Notification permission error: \(error)")
            }
            print("[EyeSafe] Notification permission granted: \(granted)")
        }
    }

    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("[EyeSafe] Notification authorization status: \(settings.authorizationStatus.rawValue)")
            print("[EyeSafe] Alert setting: \(settings.alertSetting.rawValue)")
            print("[EyeSafe] Sound setting: \(settings.soundSetting.rawValue)")
        }
    }

    func sendBreakNotification(soundEnabled: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Time for a break!"
        content.body = "Look at something 20 feet away for 20 seconds."
        if soundEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "break-start",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendBreakOverNotification(soundEnabled: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Break over"
        content.body = "Timer restarted. Keep up the good work!"
        if soundEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "break-over",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
