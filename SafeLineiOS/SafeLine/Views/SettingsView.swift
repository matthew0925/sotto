import SwiftUI

/// 技術仕様書 §6「削除：設定画面から『すべてのデータをこの端末から削除』を
/// ワンタップで用意」— 加害者などに端末を確認された場合に、記録や見守り連絡先を
/// 即座に消せることが安全確保に直結するため、確認は1段階のみに留めている。
struct SettingsView: View {
    @EnvironmentObject var checkInManager: CheckInManager
    @EnvironmentObject var journalStore: JournalStore
    @State private var showingEraseConfirm = false
    @State private var didErase = false

    private let intervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("30秒", 30), ("1分", 60), ("2分", 120), ("5分", 300), ("10分", 600)
    ]

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("設定")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("このアプリはアカウント登録をせず、データはこの端末にのみ暗号化して保存されます。サーバーには何も送信されません。")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))

                    locationIntervalSection

                    Button(role: .destructive) {
                        showingEraseConfirm = true
                    } label: {
                        Text("この端末からすべてのデータを削除")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.safeCoral.opacity(0.15))
                            .foregroundColor(.safeCoral)
                            .cornerRadius(12)
                    }

                    Text("記録（ジャーナル）と見守り連絡先を削除します。進行中のチェックインも停止します。")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.4))

                    if didErase {
                        Text("削除しました。")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.safeTeal)
                    }
                }
                .padding(20)
            }
        }
        .confirmationDialog("この端末からすべてのデータを削除しますか？",
                             isPresented: $showingEraseConfirm,
                             titleVisibility: .visible) {
            Button("削除する", role: .destructive) {
                journalStore.eraseAll()
                checkInManager.eraseSavedData()
                didErase = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    private var locationIntervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("見守り中の位置情報 更新間隔")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Text("短くするほど「今すぐ連絡先に知らせる」時の位置がより新しくなりますが、バッテリー消費が増えます。")
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.5))

            Picker("更新間隔", selection: Binding(
                get: { checkInManager.locationManager.updateInterval },
                set: { checkInManager.locationManager.updateInterval = $0 }
            )) {
                ForEach(intervalOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}
