import SwiftUI
import MessageUI

struct CheckInView: View {
    @EnvironmentObject var manager: CheckInManager
    @State private var selectedMinutes: Int = 30
    @State private var showingMessageComposer = false

    private let presets = [15, 30, 60, 120]

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("見守りチェックイン")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("一人になる予定がある時間の前にセットしておくと、時間内に「無事です」を押さない限り、指定した連絡先に知らせる準備ができます。")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))

                    timerDisplay

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { min in
                            presetButton(min)
                        }
                    }
                    .opacity(manager.isActive ? 0.4 : 1)
                    .disabled(manager.isActive)

                    field(title: "知らせる相手（電話番号）") {
                        TextField("090-1234-5678", text: $manager.contactNumber)
                            .keyboardType(.phonePad)
                    }
                    .disabled(manager.isActive)

                    field(title: "送るメッセージ") {
                        TextEditor(text: $manager.contactMessage)
                            .frame(height: 70)
                    }
                    .disabled(manager.isActive)

                    Button(action: primaryAction) {
                        Text(manager.isActive ? "無事です（チェックインを完了）" : "この内容でチェックインを開始")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.safeTeal)
                            .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                            .cornerRadius(12)
                    }

                    if manager.isActive {
                        Button {
                            showingMessageComposer = true
                        } label: {
                            Text("今すぐ連絡先に知らせる")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.safeCoral.opacity(0.15))
                                .foregroundColor(.safeCoral)
                                .cornerRadius(12)
                        }

                        locationStatus
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showingMessageComposer) {
            if MFMessageComposeViewController.canSendText() {
                MessageComposerView(recipient: manager.contactNumber,
                                     body: manager.contactMessage,
                                     mapsLink: manager.locationManager.mapsLink)
            }
        }
        .onChange(of: manager.wantsToSendAlert) { _, wants in
            if wants {
                showingMessageComposer = true
                manager.wantsToSendAlert = false
            }
        }
    }

    private var locationStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 11))
            Text(locationStatusText)
                .font(.system(size: 11.5))
        }
        .foregroundColor(.white.opacity(0.45))
    }

    private var locationStatusText: String {
        guard let updated = manager.locationManager.lastUpdated else {
            return "位置情報を取得中…"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "現在地を \(formatter.string(from: updated)) に更新（送信時に自動で添付されます）"
    }

    private var timerDisplay: some View {
        VStack(spacing: 4) {
            Text(formatted(manager.isActive ? manager.remainingSeconds : TimeInterval(selectedMinutes * 60)))
                .font(.system(size: 52, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            Text(manager.isActive ? "\(Int(manager.remainingSeconds/60))分以内に「無事です」を押してください" : "タイマー未開始")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func presetButton(_ minutes: Int) -> some View {
        let isSelected = selectedMinutes == minutes
        return Button { selectedMinutes = minutes } label: {
            Text(minutes < 60 ? "\(minutes)分" : "\(minutes/60)時間")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.safeTeal.opacity(0.18) : Color.white.opacity(0.05))
                .foregroundColor(isSelected ? .safeTeal : .white.opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.safeTeal : .clear, lineWidth: 1)
                )
        }
    }

    private func field<V: View>(title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
            content()
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .foregroundColor(.white)
        }
    }

    private func primaryAction() {
        if manager.isActive {
            manager.markSafe()
        } else {
            guard !manager.contactNumber.isEmpty else { return }
            manager.start(minutes: selectedMinutes, contact: manager.contactNumber, message: manager.contactMessage)
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

/// Wraps MFMessageComposeViewController — this is the one-tap-confirm SMS path
/// triggered from the "連絡先に知らせる" notification action per iOS's no-silent-send rule.
struct MessageComposerView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let mapsLink: String?

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = [recipient]
        if let mapsLink {
            vc.body = body + "\n現在地: \(mapsLink)"
        } else {
            vc.body = body + "（現在地の共有はお使いの地図アプリからお願いします）"
        }
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                           didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}
