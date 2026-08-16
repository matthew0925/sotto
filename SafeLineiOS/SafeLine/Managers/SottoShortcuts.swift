import AppIntents
import SwiftUI

/// Siri / Shortcuts / Action Button entry points. Both intents only open the
/// app to the relevant screen via the existing `sotto://` deep link — the
/// same mechanism SottoWidget already uses — rather than sending an alert or
/// starting a check-in on their own. Every alert-sending action in this app
/// requires an explicit human tap once the screen is open; voice/Shortcuts
/// invocation is a faster way to *reach* that screen hands-free, not a way
/// to skip the confirmation step.
struct OpenSottoIntent: AppIntent {
    static var title: LocalizedStringResource = "そっとを開く"
    static var description = IntentDescription(
        "そっとのホーム画面を開きます。発信やメッセージ送信は行いません。"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OpenSOSIntent: AppIntent {
    static var title: LocalizedStringResource = "110番への電話画面を開く"
    static var description = IntentDescription(
        "110番へ電話できるホーム画面を開きます。自動で発信することはありません。"
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "sotto://sos") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct StartCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "見守りチェックインを開く"
    static var description = IntentDescription(
        "見守りチェックインの設定画面を開きます。開始するにはアプリ内での操作が必要です。"
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "sotto://checkin") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// A transient value returned to Apple's Shortcuts app. Each property becomes
/// a Magic Variable field, allowing an automation to branch on `isOverdue`
/// and pass `recipients` / `message` into the system Send Message action.
struct CheckInAutomationInfo: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "見守り情報")
    static var defaultQuery = CheckInAutomationInfoQuery()

    let id: String

    @Property(title: "見守り中")
    var isActive: Bool

    @Property(title: "期限超過")
    var isOverdue: Bool

    @Property(title: "終了時刻")
    var deadline: Date?

    @Property(title: "送信先")
    var recipients: [String]

    @Property(title: "メッセージ")
    var message: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "現在の見守り情報")
    }

    init(snapshot: CheckInManager.AutomationSnapshot) {
        id = "current"
        isActive = snapshot.isActive
        isOverdue = snapshot.isOverdue
        deadline = snapshot.deadline
        recipients = snapshot.recipients
        message = snapshot.message
    }
}

struct CheckInAutomationInfoQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CheckInAutomationInfo] {
        guard identifiers.contains("current") else { return [] }
        return [CheckInAutomationInfo(snapshot: CheckInManager.automationSnapshot())]
    }

    func suggestedEntities() async throws -> [CheckInAutomationInfo] {
        [CheckInAutomationInfo(snapshot: CheckInManager.automationSnapshot())]
    }
}

struct GetCheckInAutomationInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "見守り情報を取得"
    static var description = IntentDescription(
        "現在の見守り状態、終了時刻、期限超過、SMSの送信先と本文を取得します。送信は行いません。"
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<CheckInAutomationInfo> {
        .result(value: CheckInAutomationInfo(snapshot: CheckInManager.automationSnapshot()))
    }
}

struct SottoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSottoIntent(),
            phrases: [
                "\(.applicationName)を開く",
                "\(.applicationName)のホームを開く"
            ],
            shortTitle: "そっとを開く",
            systemImageName: "leaf.fill"
        )
        AppShortcut(
            intent: OpenSOSIntent(),
            phrases: [
                "\(.applicationName)で110番への電話画面を開く",
                "\(.applicationName)で緊急電話を開く"
            ],
            shortTitle: "110番への電話画面",
            systemImageName: "phone.fill"
        )
        AppShortcut(
            intent: StartCheckInIntent(),
            phrases: [
                "\(.applicationName)で見守りを始める",
                "\(.applicationName)でチェックインを開く"
            ],
            shortTitle: "見守りを開く",
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: GetCheckInAutomationInfoIntent(),
            phrases: [
                "\(.applicationName)の見守り情報を取得",
                "\(.applicationName)の期限を確認"
            ],
            shortTitle: "見守り情報を取得",
            systemImageName: "message.badge.waveform.fill"
        )
    }
}
