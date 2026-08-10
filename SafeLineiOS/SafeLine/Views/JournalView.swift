import SwiftUI

struct JournalView: View {
    @EnvironmentObject var store: JournalStore
    @State private var text: String = ""
    @State private var date: Date = Date()

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("記録（この端末のみ）")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("気になったこと、違和感、出来事の日時や状況を残せます。クラウドには送信されません。誰にも見せる必要はありません。")
                        .font(.system(size: 13))
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
                        text = ""
                    } label: {
                        Text("この端末に保存")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.safeTeal)
                            .foregroundColor(Color(red: 0.02, green: 0.13, blue: 0.12))
                            .cornerRadius(12)
                    }

                    if store.entries.isEmpty {
                        Text("まだ記録はありません。\n何かあったとき、思い出せるうちに残しておけます。")
                            .font(.system(size: 13))
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
                                    .font(.system(size: 13))
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
}
