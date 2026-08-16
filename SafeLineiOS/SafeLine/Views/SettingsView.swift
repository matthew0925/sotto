import SwiftUI

/// Restructured as a native Form/Section list (previously a stack of custom
/// cards) as part of a deliberate declutter pass: Settings is a "calm mode"
/// screen nobody touches mid-crisis, so the priority here is *familiarity* —
/// the same grouped-list shape as iOS's own Settings app — over the more
/// custom visual language used on Home/CheckIn. Reusing the OS idiom means
/// less for a first-time user to parse, not more chrome to admire.
///
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
        NavigationStack {
            Form {
                Section {
                    Text("名前もメールも要りません。記録は暗号化してこの端末の中だけに残ります。")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(.safeTextDim)
                }
                .listRowBackground(Color.clear)

                Section("ホーム画面") {
                    NavigationLink {
                        IconPickerView(iconManager: iconManager)
                    } label: {
                        HStack {
                            Text("アイコン")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.safeText)
                            Spacer()
                            Text(iconManager.current.displayName)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.safeTextFaint)
                        }
                    }
                }
                .listRowBackground(Color.safeCardFill)

                Section {
                    Toggle(isOn: $checkInManager.dailyReminderEnabled) {
                        Text("毎日の見守りリマインダー")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.safeText)
                    }
                    .tint(.safeTeal)

                    if checkInManager.dailyReminderEnabled {
                        DatePicker("時刻", selection: $checkInManager.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .font(.system(size: 14.5, design: .rounded))
                            .foregroundColor(.safeText)

                        Stepper(value: $checkInManager.dailyReminderDurationMinutes, in: 15...240, step: 15) {
                            Text("目安の見守り時間：\(checkInManager.dailyReminderDurationMinutes)分")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.safeTextDim)
                        }
                    }

                    HStack {
                        Text("位置情報の更新間隔")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.safeText)
                        Spacer()
                        Picker("更新間隔", selection: Binding(
                            get: { checkInManager.locationManager.updateInterval },
                            set: { checkInManager.locationManager.updateInterval = $0 }
                        )) {
                            ForEach(intervalOptions, id: \.seconds) { option in
                                Text(option.label).tag(option.seconds)
                            }
                        }
                        .tint(.safeTeal)
                    }
                } header: {
                    Text("見守り")
                } footer: {
                    Text("リマインダーはタイマーを自動で開始せず、見守り画面を開くだけです。位置情報の更新間隔は、短くするほど「今すぐ知らせる」時の位置が新しくなりますが、バッテリー消費が増えます。")
                        .font(.system(size: 12.5, design: .rounded))
                }
                .listRowBackground(Color.safeCardFill)

                Section {
                    Button(role: .destructive) {
                        showingEraseConfirm = true
                    } label: {
                        Text("この端末のデータをすべて消す")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.safeCoral)

                    if didErase {
                        Text("削除しました。")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.safeTeal)
                    }
                } header: {
                    Text("データ")
                } footer: {
                    Text("記録と見守りの連絡先を、この端末から消します。今つけている見守りも止まります。この操作は取り消せません。")
                        .font(.system(size: 12.5, design: .rounded))
                }
                .listRowBackground(Color.safeCardFill)
            }
            .scrollContentBackground(.hidden)
            .background(Color.safeInk)
            .navigationTitle("設定")
        }
        .tint(.safeTeal)
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
}

/// Full-page icon picker, pushed from the "アイコン" row rather than shown
/// inline — moving a rarely-touched choice off the main Settings list so
/// that list stays scannable at a glance.
struct IconPickerView: View {
    @ObservedObject var iconManager: IconManager

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("ホーム画面の色味や他のアプリのアイコンに合わせて、目立たないデザインを選べます。名前の表示（そっと）は変わりません。")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    if !iconManager.supportsAlternateIcons {
                        Text("この端末ではアイコンの切り替えに対応していません。")
                            .font(.system(size: 13.5, design: .rounded))
                            .foregroundColor(.safeTextFaint)
                    } else {
                        VStack(spacing: 22) {
                            iconRow(Array(AppIconOption.allCases.prefix(3)))
                            iconRow(Array(AppIconOption.allCases.suffix(2)))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 20)
                        .background(Color.safeCardFill.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        if let error = iconManager.lastErrorMessage {
                            Text(error)
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundColor(.safeCoral)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("アイコン")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func iconRow(_ options: [AppIconOption]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(options) { option in
                iconChoice(option)
            }
        }
    }

    private func iconChoice(_ option: AppIconOption) -> some View {
        let isSelected = iconManager.current == option
        return Button {
            iconManager.setIcon(option)
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.safeCardFillStrong)
                    .overlay(
                        Image(option.previewAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isSelected ? Color.safeTeal : .clear, lineWidth: 2)
                    )
                Text(option.displayName)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(isSelected ? .safeTeal : .safeTextFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(height: 18, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityLabel(option.accessibilityName)
    }
}
