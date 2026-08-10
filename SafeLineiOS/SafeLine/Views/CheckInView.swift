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
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeText)

                    Text("出かける前にセットしておくと、時間になっても「無事です」を押さなければ、あなたが選んだ人にそっと知らせが届きます。")
                        .font(.system(size: 14.5, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    timerDisplay

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { min in
                            presetButton(min)
                        }
                    }
                    .opacity(manager.isActive ? 0.4 : 1)
                    .disabled(manager.isActive)

                    field(title: "知らせたい人（電話番号）") {
                        TextField("090-1234-5678", text: $manager.contactNumber)
                            .keyboardType(.phonePad)
                    }
                    .disabled(manager.isActive)

                    field(title: "伝えたいメッセージ") {
                        TextEditor(text: $manager.contactMessage)
                            .frame(height: 70)
                    }
                    .disabled(manager.isActive)

                    Button(action: primaryAction) {
                        Text(manager.isActive ? "無事です（見守りを終える）" : "この内容で見守りをはじめる")
                            .font(.system(size: 15.5, weight: .semibold, design: .rounded))
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
                            Text("今すぐ知らせる")
                                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
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
            } else {
                // This device can't compose SMS at all (no SIM/carrier plan,
                // Messages disabled, etc.) — previously this just presented an
                // empty sheet with no explanation and no way forward, which is
                // unacceptable for what's meant to be the emergency path.
                // Offer an immediate fallback instead of a dead end.
                SMSUnavailableView(contactNumber: manager.contactNumber)
            }
        }
        .onChange(of: manager.wantsToSendAlert) { wants in
            if wants {
                showingMessageComposer = true
                manager.wantsToSendAlert = false
            }
        }
    }

    private var locationStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 12.5, design: .rounded))
            Text(locationStatusText)
                .font(.system(size: 13, design: .rounded))
        }
        .foregroundColor(.safeTextFaint)
    }

    private var locationStatusText: String {
        if manager.locationManager.isPermissionDenied {
            return "現在地の共有はまだ許可されていません。設定から許可すると、知らせと一緒に現在地もそっと届けられます。"
        }
        guard let updated = manager.locationManager.lastUpdated else {
            return "現在地を確認しています…"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "現在地を \(formatter.string(from: updated)) ごろ確認しました（知らせと一緒に届きます）"
    }

    private var timerDisplay: some View {
        VStack(spacing: 4) {
            Text(formatted(manager.isActive ? manager.remainingSeconds : TimeInterval(selectedMinutes * 60)))
                .font(.system(size: 52, weight: .semibold, design: .monospaced))
                .foregroundColor(.safeText)
            Text(manager.isActive ? "\(Int(manager.remainingSeconds/60))分以内に「無事です」を教えてください" : "まだ何も始まっていません")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.safeTextFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func presetButton(_ minutes: Int) -> some View {
        let isSelected = selectedMinutes == minutes
        return Button { selectedMinutes = minutes } label: {
            Text(minutes < 60 ? "\(minutes)分" : "\(minutes/60)時間")
                .font(.system(size: 14.5, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.safeTeal.opacity(0.18) : Color.safeCardFill)
                .foregroundColor(isSelected ? .safeTeal : .safeTextDim)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.safeTeal : .clear, lineWidth: 1)
                )
        }
    }

    private func field<V: View>(title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13.5, design: .rounded)).foregroundColor(.safeTextFaint)
            content()
                .padding(10)
                .background(Color.safeCardFill)
                .cornerRadius(10)
                .foregroundColor(.safeText)
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

/// Fallback shown in place of MessageComposerView when this device can't
/// compose SMS at all. Always offers a phone call as a next step rather than
/// leaving the user at a dead end during what may be an emergency.
struct SMSUnavailableView: View {
    let contactNumber: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30, design: .rounded))
                .foregroundColor(.safeCoral)
            Text("メッセージを送ることができませんでした")
                .font(.system(size: 17.5, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("かわりに、電話でつながることができます。")
                .font(.system(size: 14.5, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if !contactNumber.isEmpty, let url = URL(string: "tel:\(contactNumber)") {
                Button {
                    UIApplication.shared.open(url)
                    dismiss()
                } label: {
                    Text("電話でつながる")
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(Color.safeTeal)
                        .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
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
