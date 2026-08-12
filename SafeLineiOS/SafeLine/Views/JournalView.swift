import SwiftUI
import PhotosUI

struct JournalView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var router: AppRouter
    @StateObject private var lock = JournalLock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var text: String = ""
    @State private var date: Date = Date()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var shareItem: ShareItem?
    /// Bound to the memo TextEditor. Tapping another tab does NOT
    /// automatically resign a TextEditor's first-responder status in
    /// SwiftUI, which previously left the keyboard covering the screen with
    /// no way to switch tabs — this plus the onChange below fixes that.
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            if lock.isUnlocked {
                content
            } else {
                lockScreen
            }
        }
        .overlay(alignment: .topTrailing) {
            if lock.isUnlocked {
                quickExitButton
            }
        }
        .onAppear { lock.authenticate() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { lock.lock() }
        }
        .onChange(of: router.selectedTab) { _ in
            isTextEditorFocused = false
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.data])
        }
    }

    /// Experimental: a persistent, always-reachable escape hatch from the
    /// most sensitive screen in the app. Pinned above the scroll content
    /// (not inside it) so it's tappable without scrolling back up first.
    /// Locks the journal again immediately — not just switching tabs — so
    /// if someone else picks the phone back up right after, they land on
    /// the Face ID prompt, not the last-viewed entry.
    private var quickExitButton: some View {
        Button {
            isTextEditorFocused = false
            lock.lock()
            router.selectedTab = .home
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.safeTextDim)
                .frame(width: 30, height: 30)
                .background(Color.safeCardFillStrong)
                .clipShape(Circle())
        }
        .accessibilityLabel("今すぐ離脱する")
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32, design: .rounded))
                .foregroundColor(.safeTeal)
            Text("記録は守られています")
                .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                .foregroundColor(.safeText)
            if let error = lock.lastError {
                Text(error)
                    .font(.system(size: 13.5, design: .rounded))
                    .foregroundColor(.safeTextFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            Button {
                lock.authenticate()
            } label: {
                Text("Face ID / パスコードで開く")
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.safeTeal)
                    .foregroundColor(.safeOnAccent)
                    .cornerRadius(12)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text("記録（あなたの端末だけに）")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeText)
                    Spacer()
                    if !store.entries.isEmpty {
                        Button {
                            let pdf = JournalExporter.makePDF(entries: store.entries)
                            shareItem = ShareItem(data: pdf)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(.safeTeal)
                        }
                    }
                }
                Text("気になったこと、違和感、出来事の日時や状況を、思い出せる範囲で少しずつ残せます。暗号化してこの端末にだけ保存され、クラウドには送りません。誰にも見せなくて大丈夫です。あなたのための記録です。")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.safeTextDim)

                DatePicker("日時", selection: $date)
                    .datePickerStyle(.compact)
                    .foregroundColor(.safeText)

                TextEditor(text: $text)
                    .focused($isTextEditorFocused)
                    .frame(height: 90)
                    .padding(8)
                    .background(Color.safeCardFill)
                    .cornerRadius(10)
                    .foregroundColor(.safeText)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完了") { isTextEditorFocused = false }
                        }
                    }

                photoPickerRow

                Button {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    store.add(text: text, date: date, photoData: selectedPhotoData)
                    // Only clear the input if the save actually succeeded —
                    // if it failed, leave the text in place so nothing typed
                    // is lost and the user can retry immediately.
                    if store.lastSaveError == nil {
                        text = ""
                        selectedPhotoData = nil
                        selectedPhotoItem = nil
                    }
                } label: {
                    Text("そっと保存する")
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.safeTeal)
                        .foregroundColor(.safeOnAccent)
                        .cornerRadius(12)
                }

                if let saveError = store.lastSaveError {
                    Text("⚠️ \(saveError)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeCoral)
                }

                if store.entries.isEmpty {
                    Text("まだ記録はありません。\n思い出せるときに、少しずつで大丈夫です。")
                        .font(.system(size: 14.5, design: .rounded))
                        .foregroundColor(.safeTextFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    ForEach(store.entries) { entry in
                        JournalEntryRow(entry: entry, store: store)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var photoPickerRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(selectedPhotoData == nil ? "写真を添付" : "写真を変更",
                      systemImage: "photo.on.rectangle")
                    .font(.system(size: 13.5, design: .rounded))
                    .foregroundColor(.safeTeal)
            }
            .onChange(of: selectedPhotoItem) { item in
                Task {
                    if let item, let data = try? await item.loadTransferable(type: Data.self) {
                        selectedPhotoData = data
                    }
                }
            }

            if let selectedPhotoData, let uiImage = UIImage(data: selectedPhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button {
                    self.selectedPhotoData = nil
                    self.selectedPhotoItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.safeTextFaint)
                }
            }
            Spacer()
        }
    }
}

/// A single journal entry row. Kept as its own view so the photo can be
/// decrypted lazily (on appear) rather than all at once when the list loads.
private struct JournalEntryRow: View {
    let entry: JournalEntry
    let store: JournalStore
    @State private var photo: UIImage?
    @State private var verified: Bool?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundColor(.safeTeal)
                Text(entry.text)
                    .font(.system(size: 14.5, design: .rounded))
                    .foregroundColor(.safeText)
                integrityFooter
            }
            .padding(.leading, 12)
            .overlay(Rectangle().fill(Color.safeTeal).frame(width: 2), alignment: .leading)
            .onAppear {
                if verified == nil {
                    verified = store.verify(entry)
                }
            }

            if entry.hasPhoto {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.safeCardFill)
                        .frame(width: 44, height: 44)
                        .onAppear {
                            if let data = store.photo(for: entry) {
                                photo = UIImage(data: data)
                            }
                        }
                }
            }
        }
        .padding(.bottom, 16)
    }

    /// Small, de-emphasized integrity marker — this screen is a "calm mode"
    /// screen (unlike Home/CheckIn, nobody is looking at it mid-crisis), so a
    /// bit more detail here is fine. Deliberately worded as a personal check,
    /// not a legal claim — see JournalStore's doc comment for why.
    private var integrityFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: verified == false ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: 9))
            Text(footerText)
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundColor(verified == false ? .safeCoral : .safeTextFaint)
        .padding(.top, 2)
    }

    private var footerText: String {
        let shortHash = String(entry.contentHash.prefix(12))
        let createdString = entry.createdAt.formatted(date: .omitted, time: .shortened)
        switch verified {
        case false: return "作成 \(createdString) ・ 変更が検出されました (\(shortHash))"
        default: return "作成 \(createdString) ・ \(shortHash)"
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let data: Data
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
