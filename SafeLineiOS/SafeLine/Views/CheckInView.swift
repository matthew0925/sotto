import SwiftUI
import MessageUI

struct CheckInView: View {
    @EnvironmentObject var manager: CheckInManager
    @EnvironmentObject var router: AppRouter
    @State private var selectedMinutes: Int = 30
    @State private var showingMessageComposer = false
    @State private var newContactName = ""
    @State private var newContactPhone = ""
    /// Set while editing an existing contact (tapped its row) rather than
    /// adding a new one — the add/save row's fields and button are shared
    /// between both flows. Previously there was no way to fix a typo in a
    /// saved contact without deleting it and re-adding from scratch.
    @State private var editingContactID: UUID?
    /// See JournalView's matching property for why this exists — a
    /// TextEditor doesn't reliably give up the keyboard on its own when the
    /// user taps another tab.
    private enum Field: Hashable { case message, contactName, contactPhone }
    @FocusState private var focusedField: Field?

    private let presets = [15, 30, 60, 120]

    /// `DateFormatter()` init is genuinely expensive (locale/calendar setup) —
    /// creating a fresh one inside a computed property that's re-evaluated on
    /// every keystroke (this view's `body` re-runs whenever `newContactName`
    /// changes) was the actual cause of the stutter reported while typing the
    /// contact name. A single cached formatter fixes it.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("見守りチェックイン")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeText)

                    Text("出かける前にセットしておくと、時間になったときに通知します。通知から登録した人へのSMS作成画面を開けます。")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    Label("SMSは自動送信されません。作成画面で内容を確認し、送信を押してください。", systemImage: "hand.tap")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(.safeTextDim)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.safeCardFill)
                        .cornerRadius(10)

                    timerDisplay

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { min in
                            presetButton(min)
                        }
                    }
                    .opacity(manager.isActive ? 0.4 : 1)
                    .disabled(manager.isActive)

                    contactsSection

                    field(title: "伝えたいメッセージ") {
                        ZStack(alignment: .topLeading) {
                            if manager.contactMessage.isEmpty {
                                Text(CheckInManager.defaultContactMessage)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.safeTextFaint)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $manager.contactMessage)
                                .focused($focusedField, equals: .message)
                                .scrollContentBackground(.hidden)
                                .frame(height: 70)
                        }
                    }
                    .disabled(manager.isActive)

                    Text("未入力の場合は、グレーの例文を使用します。目安時刻と現在地は、知らせるときに自動で追加されます。")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(.safeTextFaint)

                    Button(action: primaryAction) {
                        Text(manager.isActive ? "無事です（見守りを終える）" : manager.isStarting ? "通知を確認しています…" : "この内容で見守りをはじめる")
                            .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(manager.contacts.isEmpty && !manager.isActive ? Color.safeCardFillStrong : Color.safeTeal)
                            .foregroundColor(manager.contacts.isEmpty && !manager.isActive ? .safeTextFaint : .safeOnAccent)
                            .cornerRadius(12)
                    }
                    .disabled((manager.contacts.isEmpty && !manager.isActive) || manager.isStarting)

                    if let error = manager.lastStartError {
                        Text(error)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.safeCoral)
                            .accessibilityLabel("見守りを開始できませんでした。\(error)")
                    }

                    if manager.isActive {
                        Button {
                            showingMessageComposer = true
                        } label: {
                            Text("連絡先へのSMSを作成する")
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
            .scrollDismissesKeyboard(.interactively)
        }
        // Attached once, at the top level, rather than nested on a single field's
        // TextEditor — attaching/detaching a `.toolbar` per-field as focus moves
        // between the name/phone/message fields was forcing a keyboard-accessory
        // reconciliation on every focus change, which is what showed up as a
        // brief stutter when starting to type. One stable toolbar, shown for
        // whichever field is focused, avoids that churn and also means the name
        // and phone fields — which previously had no dismiss button at all — now
        // get a "完了" button too.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focusedField = nil }
            }
        }
        .sheet(isPresented: $showingMessageComposer) {
            if MFMessageComposeViewController.canSendText() {
                MessageComposerView(recipients: manager.contacts.map(\.phoneNumber),
                                     body: manager.contactMessage,
                                     mapsLink: manager.locationManager.mapsLink,
                                     deadline: manager.endDate)
            } else {
                // This device can't compose SMS at all (no SIM/carrier plan,
                // Messages disabled, etc.) — previously this just presented an
                // empty sheet with no explanation and no way forward, which is
                // unacceptable for what's meant to be the emergency path.
                // Offer an immediate fallback instead of a dead end.
                SMSUnavailableView(contacts: manager.contacts)
            }
        }
        .onChange(of: manager.wantsToSendAlert) { wants in
            if wants {
                showingMessageComposer = true
                manager.wantsToSendAlert = false
            }
        }
        .onAppear {
            if let pending = manager.pendingStartMinutes {
                selectedMinutes = presets.min(by: { abs($0 - pending) < abs($1 - pending) }) ?? pending
                manager.pendingStartMinutes = nil
            }
            presentPendingAlertIfNeeded()
        }
        .onChange(of: router.selectedTab) { _ in
            focusedField = nil
        }
    }

    private func presentPendingAlertIfNeeded() {
        guard manager.wantsToSendAlert else { return }
        showingMessageComposer = true
        manager.wantsToSendAlert = false
    }

    // MARK: - Contacts

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("知らせたい人")
                .font(.system(size: 13.5, design: .rounded))
                .foregroundColor(.safeTextFaint)

            if manager.contacts.isEmpty {
                Text("まだ誰も登録されていません。下から追加してください。")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.safeTextFaint)
            } else {
                ForEach(manager.contacts) { contact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.safeText)
                            Text(contact.phoneNumber)
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(.safeTextDim)
                        }
                        Spacer()
                        if !manager.isActive {
                            Button {
                                manager.contacts.removeAll { $0.id == contact.id }
                                if editingContactID == contact.id {
                                    cancelEditingContact()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.safeTextFaint)
                            }
                            .accessibilityLabel("\(contact.name)を削除")
                        }
                    }
                    .padding(10)
                    .background(editingContactID == contact.id ? Color.safeCardFillStrong : Color.safeCardFill)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(editingContactID == contact.id ? Color.safeTeal : Color.clear, lineWidth: 1.5)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !manager.isActive else { return }
                        editingContactID = contact.id
                        newContactName = contact.name
                        newContactPhone = contact.phoneNumber
                        focusedField = .contactName
                    }
                }
            }

            if !manager.isActive {
                HStack(spacing: 8) {
                    TextField("名前", text: $newContactName)
                        .focused($focusedField, equals: .contactName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .contactPhone }
                        .font(.system(size: 13.5, design: .rounded))
                        .padding(10)
                        .background(Color.safeCardFill)
                        .cornerRadius(10)
                        .foregroundColor(.safeText)
                        .frame(maxWidth: .infinity)

                    TextField("電話番号", text: $newContactPhone)
                        .focused($focusedField, equals: .contactPhone)
                        .keyboardType(.phonePad)
                        .font(.system(size: 13.5, design: .rounded))
                        .padding(10)
                        .background(Color.safeCardFill)
                        .cornerRadius(10)
                        .foregroundColor(.safeText)
                        .frame(maxWidth: .infinity)

                    if editingContactID != nil {
                        Button {
                            cancelEditingContact()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 26))
                                .foregroundColor(.safeTextFaint)
                        }
                        .accessibilityLabel("編集をキャンセル")
                    }

                    Button {
                        saveContact()
                    } label: {
                        Image(systemName: editingContactID == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.safeTeal)
                    }
                    .accessibilityLabel(editingContactID == nil ? "連絡先を追加" : "変更を保存")
                    .disabled(newContactPhone.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveContact() {
        let phone = newContactPhone.trimmingCharacters(in: .whitespaces)
        guard !phone.isEmpty else { return }
        let name = newContactName.trimmingCharacters(in: .whitespaces)
        let resolvedName = name.isEmpty ? "連絡先" : name

        if let editingContactID, let index = manager.contacts.firstIndex(where: { $0.id == editingContactID }) {
            manager.contacts[index].name = resolvedName
            manager.contacts[index].phoneNumber = phone
        } else {
            manager.contacts.append(EmergencyContact(name: resolvedName, phoneNumber: phone))
        }
        cancelEditingContact()
    }

    private func cancelEditingContact() {
        editingContactID = nil
        newContactName = ""
        newContactPhone = ""
        focusedField = nil
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
            return "現在地の共有はまだ許可されていません。設定から許可すると、SMS本文へ現在地を追加できます。"
        }
        guard let updated = manager.locationManager.lastUpdated else {
            return "現在地を確認しています…"
        }
        return "現在地を \(Self.timeFormatter.string(from: updated)) ごろ確認しました（SMS本文へ追加します）"
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
            guard !manager.contacts.isEmpty else { return }
            manager.start(minutes: selectedMinutes, contacts: manager.contacts, message: manager.contactMessage)
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
    let contacts: [EmergencyContact]
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
                .foregroundColor(.safeTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ForEach(contacts) { contact in
                if let url = URL(string: "tel:\(contact.phoneNumber)") {
                    Button {
                        UIApplication.shared.open(url)
                        dismiss()
                    } label: {
                        Text("\(contact.name)に電話をかける")
                            .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.safeTeal)
                            .foregroundColor(.safeOnAccent)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
    }
}

/// Wraps MFMessageComposeViewController — this is the one-tap-confirm SMS path
/// triggered from the "連絡先に知らせる" notification action per iOS's no-silent-send rule.
struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let mapsLink: String?
    /// The active check-in's `endDate`, if any — the recipient otherwise has
    /// no way to know how long to wait before worrying. Rendered as a plain
    /// "HH:mm までに" clock time rather than a relative "◯分後" duration,
    /// since the recipient reads this message at some unknown point after
    /// it's sent, not at the moment it's composed.
    let deadline: Date?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        let enteredMessage = body.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = enteredMessage.isEmpty ? CheckInManager.defaultContactMessage : enteredMessage
        if let deadline {
            // The user's own message (e.g. "時間までに連絡がなければ確認して。")
            // already asks for the same thing in their own words — repeating
            // "連絡がなければ確認してください" here just duplicates it. This adds
            // only the concrete time that message's "時間まで" is pointing at.
            text += "\n（見守りの目安時刻: \(Self.timeFormatter.string(from: deadline))）"
        }
        if let mapsLink {
            text += "\n現在地: \(mapsLink)"
        } else {
            text += "（現在地の共有はお使いの地図アプリからお願いします）"
        }
        vc.body = text
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
