import SwiftUI
import UserNotifications

@main
struct SafeLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var journalStore = JournalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.checkInManager)
                .environmentObject(journalStore)
        }
    }
}

/// Owns `CheckInManager` (rather than a SwiftUI `@StateObject`) because the
/// notification response delegate below needs to reach it directly — the
/// "無事です" / "連絡先に知らせる" actions on the timeout notification can fire
/// while the app is backgrounded, well outside any view's lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let checkInManager = CheckInManager()

    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        return true
    }

    // Show the check-in timeout notification even if the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        // UNUserNotificationCenterDelegate callbacks are not documented to
        // arrive on the main thread. checkInManager's @Published properties
        // must only be mutated on main — this is the "無事です" /
        // "連絡先に知らせる" path, the two most safety-critical actions in
        // the app, so this dispatch is not optional polish.
        DispatchQueue.main.async { [checkInManager] in
            switch response.actionIdentifier {
            case CheckInManager.safeActionId:
                checkInManager.markSafe()
            case CheckInManager.sendActionId:
                checkInManager.requestSendAlert()
            default:
                break
            }
        }
        completionHandler()
    }
}
