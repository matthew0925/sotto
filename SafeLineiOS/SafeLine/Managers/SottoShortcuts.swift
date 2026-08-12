import AppIntents
import SwiftUI

/// Siri / Shortcuts / Action Button entry points. Both intents only open the
/// app to the relevant screen via the existing `sotto://` deep link — the
/// same mechanism SottoWidget already uses — rather than sending an alert or
/// starting a check-in on their own. Every alert-sending action in this app
/// requires an explicit human tap once the screen is open; voice/Shortcuts
/// invocation is a faster way to *reach* that screen hands-free, not a way
/// to skip the confirmation step.
struct OpenSOSIntent: AppIntent {
    static var title: LocalizedStringResource = "SOSを開く"
    static var description = IntentDescription(
        "長押しでSOSを送れるホーム画面を開きます。自動で発信することはありません。"
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
            intent: OpenSOSIntent(),
            phrases: [
                "\(.applicationName)でSOSを開く",
                "\(.applicationName)を開いて助けを呼ぶ"
            ],
            shortTitle: "SOSを開く",
            systemImageName: "exclamationmark.triangle.fill"
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
