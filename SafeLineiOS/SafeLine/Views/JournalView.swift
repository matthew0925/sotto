import SwiftUI

struct JournalView: View {
    @EnvironmentObject var store: JournalStore
    @StateObject private var lock = JournalLock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var text: String = ""
    @State private var date: Date = Date()

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            if lock.isUnlocked {
                content
            } else {
                lockScreen
            }
        }
        .onAppear { lock.authenticate() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { lock.lock() }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32, design: .rounded))
                .foregroundColor(.safeTeal)
            Text("記録は守られています")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            if let error = lock.lastError {
                Text(error)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            Button {
                lock.authenticate()
            } label: {
                Text("Face ID / パスコードで開く")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.safeTeal)
                    .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                    .cornerRadius(12)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("記録（あなたの端末だけに）")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("気になったこと、違和感、出来事の日時や状況を、思い出せる範囲で少しずつ残せます。暗号化してこの端末にだけ保存され、クラウドには送りません。誰にも見せなくて大丈夫です。あなたのための記録です。")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                DatePicker("日時", selection: $date)
                    .datePickerStyle(.compact)
                    .foregroundColor(.white)

                TextEditor(text: $text)
                    .frame(height: 90)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .foregroundColor(.white)

                Button {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    store.add(text: text, date: date)
                    // Only clear the input if the save actually succeeded —
                    // if it failed, leave the text in place so nothing typed
                    // is lost and the user can retry immediately.
                    if store.lastSaveError == nil {
                        text = ""
                    }
                } label: {
                    Text("そっと保存する")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.safeTeal)
                        .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                        .cornerRadius(12)
                }

                if let saveError = store.lastSaveError {
                    Text("⚠️ \(saveError)")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeCoral)
                }

                if store.entries.isEmpty {
                    Text("まだ記録はありません。\n思い出せるときに、少しずつで大丈夫です。")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.safeTeal)
                            Text(entry.text)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 12)
                        .overlay(Rectangle().fill(Color.safeTeal).frame(width: 2), alignment: .leading)
                    }
                }
            }
            .padding(20)
        }
    }
}
