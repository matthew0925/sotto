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
    }
}
