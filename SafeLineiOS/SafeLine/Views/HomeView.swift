import SwiftUI

/// SOS is intentionally NOT gated behind "check-in mode" — most incidents involve someone
/// the user already knows, often indoors, not just "walking home alone at night".
/// So this button must be reachable the instant the app opens, in any context.
struct HomeView: View {
    @EnvironmentObject var manager: CheckInManager
    @EnvironmentObject var router: AppRouter
    @Environment(\.colorScheme) private var colorScheme
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    private let holdDuration: TimeInterval = 1.5

    /// Dark near-black reads fine against the coral SOS button in Dark Mode
    /// (7.1:1), but Light Mode's slightly deeper coral only clears 3.96:1
    /// against it — under the 4.5:1 AA minimum for this text size. White
    /// clears 4.6:1 there, so swap per color scheme rather than picking one
    /// color that fails contrast in either appearance.
    private var sosTextColor: Color {
        colorScheme == .dark ? Color(red: 0.16, green: 0.04, blue: 0.02) : .white
    }

    /// Redesigned so the SOS button is the vertical center of the screen —
    /// the one thing this screen exists for — rather than top-anchored above
    /// a long explanation. Two flexible Spacers do the centering; the small
    /// label at the very top and the quick-card pinned at the bottom stay
    /// out of the way instead of competing with it for attention.
    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("いつでも、そばに")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.safeTextFaint)
                    .tracking(1)
                    .padding(.top, 20)

                Spacer()

                VStack(spacing: 22) {
                    sosButton
                    Text("押している間だけ発信準備が進みます。離せば止まります。")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(.safeTextFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }

                Spacer()

                VStack(spacing: 12) {
                    checkinQuickCard
                    quickCard(
                        title: "☎️ #8891 に電話",
                        desc: "性犯罪・性暴力被害者のためのワンストップ支援センター。24時間365日、通話無料。",
                        actionTitle: "今すぐ電話"
                    ) {
                        callNumber("8891")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var sosButton: some View {
        ZStack {
            Circle()
                .stroke(Color.safeCoral.opacity(0.25), lineWidth: 1.5)
                .frame(width: 196, height: 196)

            Circle()
                .fill(
                    RadialGradient(colors: [Color(white: 1.0, opacity: 0.35), .clear],
                                   center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: 100)
                )
                .background(Circle().fill(Color.safeCoral))
                .frame(width: 168, height: 168)
                .overlay(
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(Color.black.opacity(0.25), lineWidth: 168)
                        .clipShape(Circle())
                )
                .overlay(
                    VStack(spacing: 4) {
                        Text("長押しでSOS")
                            .font(.system(size: 17.5, weight: .semibold, design: .rounded))
                        Text("1.5秒、ゆっくり長押し")
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .opacity(0.75)
                    }
                    .foregroundColor(sosTextColor)
                )
                .shadow(color: Color.safeCoral.opacity(0.35), radius: 24, y: 12)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
        // The 1.5s hold-to-confirm is meant to prevent an accidental touch from
        // dialing 110 — but a DragGesture has no built-in VoiceOver equivalent,
        // so without this, a VoiceOver user could not activate the single most
        // important control in the app at all. VoiceOver's own double-tap is
        // already a deliberate, two-step action (navigate to the element, then
        // activate it), so it serves the same "not an accident" purpose the
        // hold serves for sighted/typical touch — no separate hold requirement
        // needed here.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SOS")
        .accessibilityHint("ダブルタップすると、110番への発信準備が整います")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            triggerSOS()
        }
    }

    private func startHold() {
        guard holdTimer == nil else { return }
        let start = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(start)
            holdProgress = min(1.0, elapsed / holdDuration)
            if holdProgress >= 1.0 {
                timer.invalidate()
                holdTimer = nil
                triggerSOS()
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
    }

    private func triggerSOS() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        withAnimation { holdProgress = 0 }
        callNumber("110")
        // Design note: iOS requires a visible, confirmable action for both calls and
        // SMS — there is no silent background dispatch. Treat this as the primary,
        // most reliable escalation path rather than a background side-channel.
        //
        // 110 (police), not #8891: #8891 is a consultation line, not a dispatch
        // number, so an action explicitly framed as "SOS" needs to reach someone
        // who can actually respond. #8891 stays one tap away via the quick-card
        // below for anyone who wants support rather than police involvement.
    }

    private func callNumber(_ number: String) {
        guard let url = URL(string: "tel:\(number)") else { return }
        UIApplication.shared.open(url)
    }

    /// The prototype has always had this card; the real app's Home screen
    /// never did, leaving the tab bar as the only way to reach check-in from
    /// Home. Mirrors the prototype's layout: status chip + a button that
    /// only navigates to the 見守り tab, never starts a check-in by itself.
    private var checkinQuickCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📍 帰宅チェックイン")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.safeText)
                Spacer()
                Text(manager.isActive ? "見守り中" : "オフ")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(manager.isActive ? Color.safeTeal.opacity(0.18) : Color.safeCardFillStrong)
                    .foregroundColor(manager.isActive ? .safeTeal : .safeTextFaint)
                    .cornerRadius(99)
            }
            Text("時間になっても「無事です」を押さなければ、あなたが選んだ人に現在地とともにそっと知らせが届きます。")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.safeTextDim)
            Button {
                router.selectedTab = .checkin
            } label: {
                Text(manager.isActive ? "見守りを確認する" : "設定する")
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.safeTeal)
                    .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.safeCardFill)
        .cornerRadius(18)
    }

    private func quickCard(title: String, desc: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.safeText)
            Text(desc).font(.system(size: 14, design: .rounded)).foregroundColor(.safeTextDim)
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.safeTeal)
                    .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.safeCardFill)
        .cornerRadius(18)
    }
}
