import SwiftUI

struct ContentView: View {
    @StateObject private var checkInManager = CheckInManager()
    @StateObject private var journalStore = JournalStore()

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(checkInManager)
                .tabItem { Label("ホーム", systemImage: "house.fill") }

            CheckInView()
                .environmentObject(checkInManager)
                .tabItem { Label("見守り", systemImage: "clock.fill") }

            ResourcesView()
                .tabItem { Label("相談窓口", systemImage: "phone.fill") }

            JournalView()
                .environmentObject(journalStore)
                .tabItem { Label("記録", systemImage: "note.text") }
        }
        .tint(.safeTeal)
    }
}

extension Color {
    // Matches the visual language of the web prototype (calm ink/teal, coral for urgency).
    static let safeInk = Color(red: 0x12/255, green: 0x17/255, blue: 0x2B/255)
    static let safeTeal = Color(red: 0x2E/255, green: 0xC4/255, blue: 0xB6/255)
    static let safeCoral = Color(red: 0xFF/255, green: 0x6B/255, blue: 0x5B/255)
}
