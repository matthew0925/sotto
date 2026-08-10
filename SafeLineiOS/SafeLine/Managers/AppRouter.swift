import Foundation

enum AppTab: Hashable {
    case home, checkin, resources, journal, settings
}

/// Central place for anything that needs to change *which screen is showing*
/// from outside the normal view hierarchy — a widget tap (`sotto://` deep
/// link), a notification action, or the daily check-in reminder. Views read
/// `selectedTab` as the TabView's selection binding.
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home

    /// Handles `sotto://sos` and `sotto://checkin` from SottoWidget (see the
    /// widget extension). Only ever switches tabs — it deliberately never
    /// triggers the SOS call or starts a check-in by itself, so opening the
    /// app from a widget always ends with an explicit human tap, same as
    /// every other alert-sending path in this app.
    func handle(url: URL) {
        guard url.scheme == "sotto" else { return }
        switch url.host {
        case "sos":
            selectedTab = .home
        case "checkin":
            selectedTab = .checkin
        default:
            break
        }
    }
}
