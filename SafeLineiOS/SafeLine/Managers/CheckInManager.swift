import Foundation
import UserNotifications
import Combine
import Security

/// The app itself cannot silently send an SMS from the background. Its standard
/// timeout flow is:
///   1. Schedule a local notification for `endDate`.
///   2. If the user is safe, they cancel before it fires (`markSafe()`).
///   3. If it fires, the notification itself carries a one-tap action that opens the
///      app straight into the pre-filled SMS compose screen — the fastest path iOS allows.
/// An optional user-created Apple Shortcuts automation can separately read the
/// overdue state and message via `GetCheckInAutomationInfoIntent`.
///
/// While a check-in is active, `locationManager` keeps refreshing its fix (see that
/// class for the background-tracking caveat) so the alert, whenever it's actually
/// sent, carries a location close to real-time rather than a stale one from when
/// the timer started.
final class CheckInManager: ObservableObject {
    struct AutomationSnapshot {
        let isActive: Bool
        let isOverdue: Bool
        let deadline: Date?
        let recipients: [String]
        let message: String
    }
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
    static let defaultContactMessage = "見守りをお願いしています。連絡が取れない場合は、電話で確認してください。"
    private static let legacyDefaultContactMessage = "◯◯からの帰り道。時間までに連絡がなければ確認して。"
    private static let dailyReminderEnabledKey = "sotto.checkin.dailyReminder.enabled"
    private static let dailyReminderHourKey = "sotto.checkin.dailyReminder.hour"
    private static let dailyReminderMinuteKey = "sotto.checkin.dailyReminder.minute"
    private static let dailyReminderDurationKey = "sotto.checkin.dailyReminder.durationMinutes"
    private static let dailyReminderNotificationId = "safeline.checkin.dailyReminder"
    private static let activeKey = "sotto.checkin.active"
    private static let endDateKey = "sotto.checkin.endDate"

    /// Read-only bridge used by App Intents. Shortcuts can ask Sotto for the
    /// latest deadline and message at run time, so ending a check-in prevents
    /// a previously configured automation from sending stale information.
    static func automationSnapshot(now: Date = Date()) -> AutomationSnapshot {
        let storedActive = UserDefaults.standard.bool(forKey: activeKey)
        let deadline = UserDefaults.standard.object(forKey: endDateKey) as? Date
        // A partially written/corrupt state with no deadline can never become
        // overdue. Treat it as inactive so contacts are not exposed through
        // Shortcuts indefinitely.
        let isActive = storedActive && deadline != nil
        let contacts: [EmergencyContact]
        if let data = KeychainStore.get(contactsKey),
           let decoded = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            contacts = decoded
        } else {
            contacts = []
        }

        let savedMessage = KeychainStore.getString(messageKey) ?? ""
        var message = savedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty { message = defaultContactMessage }
        if let deadline {
            message += "\n（見守りの目安時刻: \(automationTimeFormatter.string(from: deadline))）"
        }

        return AutomationSnapshot(
            isActive: isActive,
            isOverdue: isActive && deadline.map { $0 <= now } == true,
            deadline: isActive ? deadline : nil,
            recipients: isActive && deadline.map { $0 <= now } == true
                ? contacts.compactMap(\.dialablePhoneNumber)
                : [],
            message: isActive && deadline.map { $0 <= now } == true ? message : ""
        )
    }

    private static let automationTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 H:mm"
        return formatter
    }()

    @Published var isActive: Bool = false
    @Published var endDate: Date?
    @Published var remainingSeconds: TimeInterval = 0
    @Published private(set) var isStarting = false
    @Published private(set) var lastStartError: String?

    @Published var contacts: [EmergencyContact] {
        didSet {
            if let data = try? JSONEncoder().encode(contacts) {
                KeychainStore.set(data, for: Self.contactsKey,
                                  accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
            }
        }
    }
    @Published var contactMessage: String {
        didSet {
            KeychainStore.setString(contactMessage, for: Self.messageKey,
                                    accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }
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
                requestNotificationPermissionIfNeeded()
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
    /// Prevents the foreground ticker from repeatedly asking the view to
    /// present the composer after the deadline has elapsed.
    private var didRequestComposerForCurrentTimeout = false
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

        let savedMessage = KeychainStore.getString(Self.messageKey)
        if savedMessage == nil
            || savedMessage == Self.legacyDefaultContactMessage
            || savedMessage == Self.defaultContactMessage {
            contactMessage = ""
        } else {
            contactMessage = savedMessage ?? ""
        }

        dailyReminderEnabled = UserDefaults.standard.bool(forKey: Self.dailyReminderEnabledKey)
        let savedHour = UserDefaults.standard.object(forKey: Self.dailyReminderHourKey) as? Int ?? 21
        let savedMinute = UserDefaults.standard.object(forKey: Self.dailyReminderMinuteKey) as? Int ?? 0
        var comps = DateComponents()
        comps.hour = savedHour
        comps.minute = savedMinute
        dailyReminderTime = Calendar.current.date(from: comps) ?? Date()
        let savedDuration = UserDefaults.standard.object(forKey: Self.dailyReminderDurationKey) as? Int ?? 30
        dailyReminderDurationMinutes = savedDuration

        // Shortcuts automations commonly run while the screen is locked.
        // Migrate existing check-in values from WhenUnlocked to
        // AfterFirstUnlock while retaining ThisDeviceOnly (no Keychain sync).
        if let data = try? JSONEncoder().encode(contacts) {
            KeychainStore.set(data, for: Self.contactsKey,
                              accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }
        KeychainStore.setString(contactMessage, for: Self.messageKey,
                                accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)

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

        if UserDefaults.standard.bool(forKey: Self.activeKey),
           let savedEndDate = UserDefaults.standard.object(forKey: Self.endDateKey) as? Date {
            isActive = true
            endDate = savedEndDate
            remainingSeconds = max(0, savedEndDate.timeIntervalSinceNow)
            if savedEndDate <= Date() {
                wantsToSendAlert = true
                didRequestComposerForCurrentTimeout = true
            }
            startTicker()
            locationManager.startTracking()
        }
    }

    private func registerNotificationCategories() {
        let safeAction = UNNotificationAction(identifier: Self.safeActionId, title: "無事です", options: [])
        let sendAction = UNNotificationAction(identifier: Self.sendActionId, title: "SMS作成画面を開く", options: [.foreground])
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
        guard !isStarting, !isActive else { return }
        guard (1...1440).contains(minutes) else {
            lastStartError = "見守り時間を選び直してください。"
            return
        }
        let validContacts = contacts.filter { $0.dialablePhoneNumber != nil }
        guard !validContacts.isEmpty else {
            lastStartError = "送信できる電話番号を1件以上登録してください。"
            return
        }
        self.contacts = validContacts
        contactMessage = message
        pendingStartMinutes = nil
        lastStartError = nil
        isStarting = true
        let target = Date().addingTimeInterval(TimeInterval(minutes * 60))
        authorizeAndScheduleTimeout(at: target)
    }

    /// Only prompts if the user has never been asked — requesting again after
    /// a denial just reshows the same system dialog with no extra context and
    /// trains people to dismiss prompts on reflex. Called right before the
    /// first notification this app actually needs is scheduled (check-in
    /// start, or turning on the daily reminder) rather than at launch, so the
    /// system prompt always has an obvious reason attached to it.
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Called when the user taps "無事です" — either in-app or from the notification action.
    func markSafe() {
        isActive = false
        endDate = nil
        remainingSeconds = 0
        wantsToSendAlert = false
        ticker?.invalidate()
        didRequestComposerForCurrentTimeout = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        locationManager.stopTracking()
        UserDefaults.standard.removeObject(forKey: Self.activeKey)
        UserDefaults.standard.removeObject(forKey: Self.endDateKey)
    }

    /// Called from the notification action, or from a manual "今すぐ連絡先に知らせる"
    /// button while a check-in is active.
    @discardableResult
    func requestSendAlert() -> Bool {
        guard isActive else { return false }
        wantsToSendAlert = true
        return true
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
        contactMessage = ""
        dailyReminderEnabled = false
    }

    private func authorizeAndScheduleTimeout(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    guard granted, error == nil else {
                        self.finishStartWithError("通知が許可されていないため、見守りを開始できません。設定アプリで通知を許可してください。")
                        return
                    }
                    center.getNotificationSettings { refreshed in
                        self.scheduleTimeoutNotification(at: date, settings: refreshed)
                    }
                }
            case .authorized, .provisional, .ephemeral:
                self.scheduleTimeoutNotification(at: date, settings: settings)
            default:
                self.finishStartWithError("通知が許可されていないため、見守りを開始できません。設定アプリで通知を許可してください。")
            }
        }
    }

    private func scheduleTimeoutNotification(at date: Date, settings: UNNotificationSettings) {
        guard settings.alertSetting == .enabled else {
            finishStartWithError("通知のバナーが無効なため、見守りを開始できません。設定アプリで通知を有効にしてください。")
            return
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])

        let content = UNMutableNotificationContent()
        content.title = "チェックインの時間になりました"
        content.body = "無事なら「無事です」を、連絡先へ伝える場合は「SMS作成画面を開く」をタップし、内容を確認して送信してください。"
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
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isStarting = false
                if error != nil {
                    self.lastStartError = "通知を登録できなかったため、見守りを開始できませんでした。もう一度お試しください。"
                    return
                }
                self.endDate = date
                self.remainingSeconds = max(0, date.timeIntervalSinceNow)
                self.isActive = true
                self.didRequestComposerForCurrentTimeout = false
                UserDefaults.standard.set(true, forKey: Self.activeKey)
                UserDefaults.standard.set(date, forKey: Self.endDateKey)
                self.startTicker()
                self.locationManager.requestPermission()
                self.locationManager.startTracking()
            }
        }
    }

    private func finishStartWithError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isStarting = false
            self?.lastStartError = message
        }
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
                if !self.didRequestComposerForCurrentTimeout {
                    self.didRequestComposerForCurrentTimeout = true
                    self.requestSendAlert()
                }
            }
        }
    }
}
