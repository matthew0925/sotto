import Foundation
import UserNotifications
import Combine

/// iOS will not let an app silently send an SMS from the background without the user
/// confirming in the Messages UI. So the "timeout" flow here is:
///   1. Schedule a local notification for `endDate`.
///   2. If the user is safe, they cancel before it fires (`markSafe()`).
///   3. If it fires, the notification itself carries a one-tap action that opens the
///      app straight into the pre-filled SMS compose screen — the fastest path iOS allows.
///
/// While a check-in is active, `locationManager` keeps refreshing its fix (see that
/// class for the background-tracking caveat) so the alert, whenever it's actually
/// sent, carries a location close to real-time rather than a stale one from when
/// the timer started.
final class CheckInManager: ObservableObject {
    static let timeoutCategoryId = "CHECKIN_TIMEOUT"
    static let sendActionId = "SEND_ALERT"
    static let safeActionId = "IM_SAFE"
    static let dailyReminderCategoryId = "DAILY_REMINDER"
    static let startCheckinActionId = "START_CHECKIN"

    private static let contactsKey = "sotto.checkin.contacts"
    /// Pre-multi-contact key, kept only so `init()` can migrate anyone who
    /// already has a single saved contact into the new array format.
    private static let legacyContactKey = "sotto.checkin.contact"
    private static let messageKey = "sotto.checkin.message"
    private static let dailyReminderEnabledKey = "sotto.checkin.dailyReminder.enabled"
    private static let dailyReminderHourKey = "sotto.checkin.dailyReminder.hour"
    private static let dailyReminderMinuteKey = "sotto.checkin.dailyReminder.minute"
    private static let dailyReminderDurationKey = "sotto.checkin.dailyReminder.durationMinutes"
    private static let dailyReminderNotificationId = "safeline.checkin.dailyReminder"

    @Published var isActive: Bool = false
    @Published var endDate: Date?
    @Published var remainingSeconds: TimeInterval = 0

    @Published var contacts: [EmergencyContact] {
        didSet {
            if let data = try? JSONEncoder().encode(contacts) {
                KeychainStore.set(data, for: Self.contactsKey)
            }
        }
    }
    @Published var contactMessage: String {
        didSet { KeychainStore.setString(contactMessage, for: Self.messageKey) }
    }

    /// Set to true when the user taps "連絡先に知らせる" on the timeout notification.
    /// CheckInView observes this to present the SMS composer, since the app may have
    /// been backgrounded when the action fired.
    @Published var wantsToSendAlert = false

    /// Set when the daily check-in reminder (or a widget deep link) is tapped,
    /// so CheckInView can pre-select a duration. Never auto-starts the timer —
    /// starting still requires the explicit "この内容で見守りをはじめる" tap,
    /// consistent with how every other alert/send action in this app works.
    @Published var pendingStartMinutes: Int?

    @Published var dailyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dailyReminderEnabled, forKey: Self.dailyReminderEnabledKey)
            if dailyReminderEnabled {
                scheduleDailyReminder()
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderNotificationId])
            }
        }
    }
    /// Hour/minute of day the reminder fires (only those two components are used).
    @Published var dailyReminderTime: Date {
        didSet {
            let cal = Calendar.current
            UserDefaults.standard.set(cal.component(.hour, from: dailyReminderTime), forKey: Self.dailyReminderHourKey)
            UserDefaults.standard.set(cal.component(.minute, from: dailyReminderTime), forKey: Self.dailyReminderMinuteKey)
            if dailyReminderEnabled {
                scheduleDailyReminder()
            }
        }
    }
    @Published var dailyReminderDurationMinutes: Int {
        didSet { UserDefaults.standard.set(dailyReminderDurationMinutes, forKey: Self.dailyReminderDurationKey) }
    }

    let locationManager = LocationManager()

    private var ticker: Timer?
    private let notificationId = "safeline.checkin.timeout"
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let data = KeychainStore.get(Self.contactsKey),
           let decoded = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            contacts = decoded
        } else if let legacyNumber = KeychainStore.getString(Self.legacyContactKey), !legacyNumber.isEmpty {
            // Migrate a pre-multi-contact install: one saved number becomes
            // the first entry rather than silently disappearing.
            contacts = [EmergencyContact(name: "連絡先", phoneNumber: legacyNumber)]
        } else {
            contacts = []
        }

        contactMessage = KeychainStore.getString(Self.messageKey)
            ?? "◯◯からの帰り道。時間までに連絡がなければ確認して。"

        dailyReminderEnabled = UserDefaults.standard.bool(forKey: Self.dailyReminderEnabledKey)
        let savedHour = UserDefaults.standard.object(forKey: Self.dailyReminderHourKey) as? Int ?? 21
        let savedMinute = UserDefaults.standard.object(forKey: Self.dailyReminderMinuteKey) as? Int ?? 0
        var comps = DateComponents()
        comps.hour = savedHour
        comps.minute = savedMinute
        dailyReminderTime = Calendar.current.date(from: comps) ?? Date()
        let savedDuration = UserDefaults.standard.object(forKey: Self.dailyReminderDurationKey) as? Int ?? 30
        dailyReminderDurationMinutes = savedDuration

        registerNotificationCategories()

        // Forward LocationManager's own @Published changes so views that only
        // observe CheckInManager (e.g. CheckInView's location status line,
        // SettingsView's interval picker) still re-render when a fix or the
        // interval setting changes.
        locationManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if dailyReminderEnabled {
            scheduleDailyReminder()
        }
    }

    private func registerNotificationCategories() {
        let safeAction = UNNotificationAction(identifier: Self.safeActionId, title: "無事です", options: [])
        let sendAction = UNNotificationAction(identifier: Self.sendActionId, title: "連絡先に知らせる", options: [.foreground, .destructive])
        let timeoutCategory = UNNotificationCategory(identifier: Self.timeoutCategoryId,
                                                       actions: [safeAction, sendAction],
                                                       intentIdentifiers: [],
                                                       options: [])

        let startAction = UNNotificationAction(identifier: Self.startCheckinActionId, title: "見守りを開く", options: [.foreground])
        let reminderCategory = UNNotificationCategory(identifier: Self.dailyReminderCategoryId,
                                                        actions: [startAction],
                                                        intentIdentifiers: [],
                                                        options: [])
        UNUserNotificationCenter.current().setNotificationCategories([timeoutCategory, reminderCategory])
    }

    func start(minutes: Int, contacts: [EmergencyContact], message: String) {
        self.contacts = contacts
        contactMessage = message
        pendingStartMinutes = nil

        let target = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endDate = target
        isActive = true
        scheduleTimeoutNotification(at: target)
        startTicker()

        locationManager.requestPermission()
        locationManager.startTracking()
    }

    /// Called when the user taps "無事です" — either in-app or from the notification action.
    func markSafe() {
        isActive = false
        endDate = nil
        remainingSeconds = 0
        ticker?.invalidate()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        locationManager.stopTracking()
    }

    /// Called from the notification action, or from a manual "今すぐ連絡先に知らせる"
    /// button while a check-in is active.
    func requestSendAlert() {
        wantsToSendAlert = true
    }

    /// Called when the daily reminder notification (or its "見守りを開く" action)
    /// is tapped, or from a widget deep link. CheckInView reads this once to
    /// pre-select a duration and then clears it.
    func requestStartCheckin(minutes: Int? = nil) {
        pendingStartMinutes = minutes ?? dailyReminderDurationMinutes
    }

    /// Used by the "この端末からすべてのデータを削除" setting.
    func eraseSavedData() {
        markSafe()
        contacts = []
        contactMessage = "◯◯からの帰り道。時間までに連絡がなければ確認して。"
        dailyReminderEnabled = false
    }

    private func scheduleTimeoutNotification(at date: Date) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])

        let content = UNMutableNotificationContent()
        content.title = "チェックインの時間になりました"
        content.body = "無事なら「無事です」を、連絡できない状況なら「連絡先に知らせる」をタップしてください。"
        // .defaultCritical requires Apple's separate Critical Alerts entitlement
        // (com.apple.developer.usernotifications.critical-alerts), which is granted
        // only after an individual request/justification to Apple and is unlikely
        // to be approved for a first submission. Using it without the entitlement
        // just silently falls back to a normal sound, so default here to avoid the
        // false impression that this notification bypasses Silent/Focus mode.
        content.sound = .default
        content.categoryIdentifier = Self.timeoutCategoryId

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Fires once a day at the configured time as a nudge to set up tonight's
    /// check-in — it does NOT start one by itself (see `requestStartCheckin`'s
    /// doc comment for why).
    private func scheduleDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderNotificationId])

        let content = UNMutableNotificationContent()
        content.title = "見守りチェックインの時間です"
        content.body = "出かける前に見守りをセットしておきますか？"
        content.sound = .default
        content.categoryIdentifier = Self.dailyReminderCategoryId

        var triggerComponents = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        triggerComponents.calendar = Calendar.current
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyReminderNotificationId, content: content, trigger: trigger)
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
