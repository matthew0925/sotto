import SwiftUI
import UserNotifications

@main
struct SafeLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var journalStore = JournalStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.checkInManager)
                .environmentObject(journalStore)
                .environmentObject(router)
                .onOpenURL { url in
                    router.handle(url: url)
                }
                .onAppear {
                    appDelegate.router = router
                }
        }
    }
}

/// Owns `CheckInManager` (rather than a SwiftUI `@StateObject`) because the
/// notification response delegate below needs to reach it directly — the
/// "無事です" / "連絡先に知らせる" actions on the timeout notification can fire
/// while the app is backgrounded, well outside any view's lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let checkInManager = CheckInManager()
    /// Set once by SafeLineApp's `.onAppear` so the notification handler
    /// below can also switch tabs (e.g. daily reminder → 見守り tab).
    weak var router: AppRouter?

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
        DispatchQueue.main.async { [checkInManager, router] in
            switch response.actionIdentifier {
            case CheckInManager.safeActionId:
                checkInManager.markSafe()
            case CheckInManager.sendActionId:
                checkInManager.requestSendAlert()
            case CheckInManager.startCheckinActionId, UNNotificationDefaultActionIdentifier
                where response.notification.request.content.categoryIdentifier == CheckInManager.dailyReminderCategoryId:
                checkInManager.requestStartCheckin()
                router?.selectedTab = .checkin
            default:
                break
            }
        }
        completionHandler()
    }
}
