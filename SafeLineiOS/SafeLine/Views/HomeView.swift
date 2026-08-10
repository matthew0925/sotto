import SwiftUI

/// SOS is intentionally NOT gated behind "check-in mode" — most incidents involve someone
/// the user already knows, often indoors, not just "walking home alone at night".
/// So this button must be reachable the instant the app opens, in any context.
struct HomeView: View {
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    private let holdDuration: TimeInterval = 1.5

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("いつでも、押せる場所を。")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("外出中でも、家の中でも。長押しで、迷わず助けを呼べます。")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                sosButton
                    .padding(.top, 12)

                Text("押している間だけ発信準備が進みます。離せば止まります。")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                quickCard(
                    title: "☎️ #8891 に電話",
                    desc: "性犯罪・性暴力被害者のためのワンストップ支援センター。24時間365日、通話無料。",
                    actionTitle: "今すぐ電話"
                ) {
                    callNumber("8891")
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
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("1.5秒、ゆっくり長押し")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .opacity(0.75)
                    }
                    .foregroundColor(Color(red: 0.16, green: 0.04, blue: 0.02))
                )
                .shadow(color: Color.safeCoral.opacity(0.35), radius: 24, y: 12)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
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
        callNumber("8891")
        // Design note: iOS requires a visible, confirmable action for both calls and
        // SMS — there is no silent background dispatch. Treat this as the primary,
        // most reliable escalation path rather than a background side-channel.
    }

    private func callNumber(_ number: String) {
        guard let url = URL(string: "tel:\(number)") else { return }
        UIApplication.shared.open(url)
    }

    private func quickCard(title: String, desc: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14.5, weight: .semibold, design: .rounded)).foregroundColor(.white)
            Text(desc).font(.system(size: 12.5, design: .rounded)).foregroundColor(.white.opacity(0.6))
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.safeTeal)
                    .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
    }
}
