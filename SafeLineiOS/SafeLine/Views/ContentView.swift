import SwiftUI

struct ContentView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("sotto.onboarding.completed") private var onboardingCompleted = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)

            CheckInView()
                .tabItem { Label("見守り", systemImage: "clock.fill") }
                .tag(AppTab.checkin)

            ResourcesView()
                .tabItem { Label("相談窓口", systemImage: "phone.fill") }
                .tag(AppTab.resources)

            JournalView()
                .tabItem { Label("記録", systemImage: "note.text") }
                .tag(AppTab.journal)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(.safeTeal)
        .onAppear {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            showOnboarding = !isUITesting && !onboardingCompleted
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                onboardingCompleted = true
                showOnboarding = false
            }
        }
    }
}

/// All tokens below are backed by Asset Catalog color sets with separate
/// light/dark values (see Assets.xcassets) so the app follows the system
/// appearance automatically. Text tokens deliberately use higher contrast
/// than the original fixed-opacity-white scheme, which read as too faint
/// against the dark background (a real "text is hard to read" report).
extension Color {
    static let safeInk = Color("Ink")
    static let safeTeal = Color("Teal")
    static let safeCoral = Color("Coral")

    /// Primary body/heading text.
    static let safeText = Color("TextPrimary")
    /// Secondary text — descriptions, field labels. Higher contrast than the
    /// old `.white.opacity(0.6)` it replaces.
    static let safeTextDim = Color("TextSecondary")
    /// Tertiary/hint text — placeholders, timestamps, empty states.
    static let safeTextFaint = Color("TextTertiary")

    /// Subtle fill for cards, inputs, inactive controls.
    static let safeCardFill = Color("CardFill")
    /// Slightly stronger fill for nested/selected surfaces.
    static let safeCardFillStrong = Color("CardFillStrong")
    /// Hairline borders/dividers.
    static let safeBorder = Color("Border")

    /// Dark text used on top of bright teal/coral filled buttons — stays
    /// constant across both themes since those accent colors are always
    /// bright enough to need dark text on them.
    static let safeOnAccent = Color(red: 0.02, green: 0.13, blue: 0.12)
}
