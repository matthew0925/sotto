import Foundation
import UserNotifications
import Combine

/// iOS will not let an app silently send an SMS from the background without the user
/// confirming in the Messages UI. So the "timeout" flow here is:
///   1. Schedule a local notification for `endDate`.
///   2. If the user is safe, they cancel before it fires (`markSafe()`).
///   3. If it fires, the notification itself carries a one-tap action that opens the
///      app straight into the pre-filled SMS compose screen — the fastest path iOS allows.
final class CheckInManager: ObservableObject {
    static let timeoutCategoryId = "CHECKIN_TIMEOUT"
    static let sendActionId = "SEND_ALERT"
    static let safeActionId = "IM_SAFE"

    @Published var isActive: Bool = false
    @Published var endDate: Date?
    @Published var remainingSeconds: TimeInterval = 0

    @Published var contactNumber: String = ""
    @Published var contactMessage: String = "◯◯からの帰り道。時間までに連絡がなければ確認して。"

    private var ticker: Timer?
    private let notificationId = "safeline.checkin.timeout"

    init() {
        registerNotificationCategory()
    }

    private func registerNotificationCategory() {
        let safeAction = UNNotificationAction(identifier: Self.safeActionId, title: "無事です", options: [])
        let sendAction = UNNotificationAction(identifier: Self.sendActionId, title: "連絡先に知らせる", options: [.foreground, .destructive])
        let category = UNNotificationCategory(identifier: Self.timeoutCategoryId,
                                               actions: [safeAction, sendAction],
                                               intentIdentifiers: [],
                                               options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func start(minutes: Int, contact: String, message: String) {
        contactNumber = contact
        contactMessage = message

        let target = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endDate = target
        isActive = true
        scheduleTimeoutNotification(at: target)
        startTicker()
    }

    /// Called when the user taps "無事です" — either in-app or from the notification action.
    func markSafe() {
        isActive = false
        endDate = nil
        remainingSeconds = 0
        ticker?.invalidate()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    private func scheduleTimeoutNotification(at date: Date) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])

        let content = UNMutableNotificationContent()
        content.title = "チェックインの時間になりました"
        content.body = "無事なら「無事です」を、連絡できない状況なら「連絡先に知らせる」をタップしてください。"
        content.sound = .defaultCritical
        content.categoryIdentifier = Self.timeoutCategoryId
        content.userInfo = ["contact": contactNumber, "message": contactMessage]

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let end = self.endDate else { return }
            self.remainingSeconds = max(0, end.timeIntervalSinceNow)
            if self.remainingSeconds <= 0 {
                self.ticker?.invalidate()
            }
        }
    }
}
