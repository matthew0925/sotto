import SwiftUI

/// SOS is intentionally NOT gated behind "check-in mode" — most incidents involve someone
/// the user already knows, often indoors, not just "walking home alone at night".
/// So this button must be reachable the instant the app opens, in any context.
struct HomeView: View {
    @EnvironmentObject var manager: CheckInManager
    @EnvironmentObject var router: AppRouter
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    private let holdDuration: TimeInterval = 1.5

    private var sosTextColor: Color {
        .safeCoral
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
                Text("必要なとき、すぐここから")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundColor(.safeTextFaint)
                    .tracking(1)
                    .padding(.top, 20)

                Spacer()

                VStack(spacing: 22) {
                    sosButton
                    Text("触れただけでは発信されません。\n1.5秒長押しすると、110番の発信確認が開きます。")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.safeTextDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                        .accessibilityIdentifier("home.emergencyExplanation")
                }

                Spacer()

                // #8891 is a support/consultation line, not an emergency dispatch
                // number — pairing it with 110 on Home implied equal urgency, and
                // its description drifted out of sync with the 相談窓口 tab's
                // copy. It already lives there, so Home no longer duplicates it.
                VStack(spacing: 12) {
                    checkinQuickCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var sosButton: some View {
        ZStack {
            Circle()
                .fill(Color.safeCardFill)
                .frame(width: 196, height: 196)
                .overlay(Circle().stroke(Color.safeCoral.opacity(0.45), lineWidth: 2))

            Circle()
                .fill(
                    RadialGradient(colors: [Color.safeCoral.opacity(0.18), Color.safeCoral.opacity(0.08)],
                                   center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: 100)
                )
                .background(Circle().fill(Color.safeCardFill))
                .frame(width: 168, height: 168)
                .overlay(Circle().stroke(Color.safeCoral.opacity(0.65), lineWidth: 2.5))
                .overlay(
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(Color.safeCoral, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(5)
                )
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("110番に電話")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Text("1.5秒長押し")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .opacity(0.75)
                    }
                    .foregroundColor(sosTextColor)
                )
                .shadow(color: Color.safeCoral.opacity(0.12), radius: 12, y: 6)
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
        .accessibilityLabel("110番に電話")
        .accessibilityHint("ダブルタップすると、110番の発信確認が開きます")
        .accessibilityIdentifier("home.emergencyCall")
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
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation { holdProgress = 0 }
        callNumber("110")
        // Design note: iOS requires a visible, confirmable action for both calls and
        // SMS — there is no silent background dispatch. Treat this as the primary,
        // most reliable escalation path rather than a background side-channel.
        //
        // 110 (police), not #8891: #8891 is a consultation line, not a dispatch
        // number, so an action explicitly framed as "SOS" needs to reach someone
        // who can actually respond. #8891 lives in 相談窓口 for anyone who wants
        // support rather than police involvement.
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
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.safeText)
                Spacer()
                Text(manager.isActive ? "見守り中" : "オフ")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(manager.isActive ? Color.safeTeal.opacity(0.18) : Color.safeCardFillStrong)
                    .foregroundColor(manager.isActive ? .safeTeal : .safeTextFaint)
                    .cornerRadius(99)
            }
            Text("時間になると通知します。通知からメッセージ作成画面を開き、内容を確認して送信できます。")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.safeTextDim)
            Button {
                router.selectedTab = .checkin
            } label: {
                Text(manager.isActive ? "見守りを確認する" : "設定する")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
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
