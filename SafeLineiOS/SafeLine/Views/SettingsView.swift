import SwiftUI

/// 技術仕様書 §6「削除：設定画面から『すべてのデータをこの端末から削除』を
/// ワンタップで用意」— 加害者などに端末を確認された場合に、記録や見守り連絡先を
/// 即座に消せることが安全確保に直結するため、確認は1段階のみに留めている。
struct SettingsView: View {
    @EnvironmentObject var checkInManager: CheckInManager
    @EnvironmentObject var journalStore: JournalStore
    @StateObject private var iconManager = IconManager()
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
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeText)

                    Text("このアプリはアカウント登録をせず、データはこの端末にのみ暗号化して保存されます。サーバーには何も送信されません。")
                        .font(.system(size: 14.5, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    appIconSection

                    locationIntervalSection

                    dailyReminderSection

                    Button(role: .destructive) {
                        showingEraseConfirm = true
                    } label: {
                        Text("この端末のデータをすべて消す")
                            .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.safeCoral.opacity(0.15))
                            .foregroundColor(.safeCoral)
                            .cornerRadius(12)
                    }

                    Text("記録と見守りの連絡先を、この端末から消します。今つけている見守りも止まります。")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.safeTextFaint)

                    if didErase {
                        Text("削除しました。")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.safeTeal)
                    }
                }
                .padding(20)
            }
        }
        .confirmationDialog("この端末のデータをすべて消しますか？",
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

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ホーム画面のアイコン")
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundColor(.safeText)

            Text("ホーム画面の色味や他のアプリのアイコンに合わせて、目立たないデザインを選べます。名前の表示（そっと）は変わりません。")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.safeTextFaint)

            if !iconManager.supportsAlternateIcons {
                Text("この端末ではアイコンの切り替えに対応していません。")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.safeTextFaint)
            } else {
                HStack(spacing: 12) {
                    ForEach(AppIconOption.allCases) { option in
                        iconChoice(option)
                    }
                }

                if let error = iconManager.lastErrorMessage {
                    Text(error)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(.safeCoral)
                }
            }
        }
        .padding(14)
        .background(Color.safeCardFill)
        .cornerRadius(14)
    }

    private func iconChoice(_ option: AppIconOption) -> some View {
        let isSelected = iconManager.current == option
        return Button {
            iconManager.setIcon(option)
        } label: {
            VStack(spacing: 6) {
                // 実際のプレビュー画像はAsset Catalogに追加してください（README §5）。
                // 画像が未追加でも枠だけは表示され、選択操作自体は動作します。
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.safeCardFillStrong)
                    .overlay(
                        Image(option.previewAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.safeTeal : .clear, lineWidth: 2)
                    )
                Text(option.displayName)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(isSelected ? .safeTeal : .safeTextFaint)
            }
        }
    }

    private var dailyReminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $checkInManager.dailyReminderEnabled) {
                Text("毎日の見守りリマインダー")
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.safeText)
            }
            .tint(.safeTeal)

            Text("決まった時間に「見守りをセットしますか？」と通知します。通知はタイマーを自動で開始せず、開くだけです。")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.safeTextFaint)

            if checkInManager.dailyReminderEnabled {
                DatePicker("時刻", selection: $checkInManager.dailyReminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .foregroundColor(.safeText)

                Stepper(value: $checkInManager.dailyReminderDurationMinutes, in: 15...240, step: 15) {
                    Text("目安の見守り時間：\(checkInManager.dailyReminderDurationMinutes)分")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(.safeTextDim)
                }
            }
        }
        .padding(14)
        .background(Color.safeCardFill)
        .cornerRadius(14)
    }

    private var locationIntervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("見守り中の位置情報 更新間隔")
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundColor(.safeText)

            Text("短くするほど「今すぐ知らせる」を押したときの位置が新しくなりますが、バッテリー消費が増えます。")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.safeTextFaint)

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
        .background(Color.safeCardFill)
        .cornerRadius(14)
    }
}
