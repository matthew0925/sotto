import SwiftUI
import CoreLocation
import UserNotifications
import AppIntents

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("sotto.onboarding.completed") private var onboardingCompleted = false
    @StateObject private var iconManager = IconManager()
    @State private var showingEraseConfirm = false
    @State private var didErase = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let intervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("30秒", 30), ("1分", 60), ("2分", 120), ("5分", 300), ("10分", 600)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("名前もメールも要りません。記録は暗号化してこの端末の中だけに残ります。")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.safeTextDim)
                }
                .listRowBackground(Color.clear)

                Section("ホーム画面") {
                    NavigationLink {
                        IconPickerView(iconManager: iconManager)
                    } label: {
                        HStack {
                            Text("アイコン")
                                .font(.system(.callout, design: .rounded))
                                .foregroundColor(.safeText)
                            Spacer()
                            Text(iconManager.current.displayName)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.safeTextFaint)
                        }
                    }
                }
                .listRowBackground(Color.safeCardFill)

                Section {
                    permissionRow(
                        title: "通知",
                        status: notificationStatusText,
                        systemImage: "bell.badge"
                    )
                    permissionRow(
                        title: "位置情報",
                        status: locationStatusText,
                        systemImage: "location"
                    )

                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        Label("iPhoneの設定を開く", systemImage: "gear")
                            .font(.system(.callout, design: .rounded))
                    }
                } header: {
                    Text("権限と端末設定")
                } footer: {
                    Text("権限は必要な機能を使うときに確認します。拒否した権限は、iPhoneの設定から変更できます。")
                        .font(.system(.caption, design: .rounded))
                }
                .listRowBackground(Color.safeCardFill)

                Section {
                    Toggle(isOn: $checkInManager.dailyReminderEnabled) {
                        Text("毎日の見守りリマインダー")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.safeText)
                    }
                    .tint(.safeTeal)

                    if checkInManager.dailyReminderEnabled {
                        DatePicker("時刻", selection: $checkInManager.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.safeText)

                        Stepper(value: $checkInManager.dailyReminderDurationMinutes, in: 15...240, step: 15) {
                            Text("目安の見守り時間：\(checkInManager.dailyReminderDurationMinutes)分")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.safeTextDim)
                        }
                    }

                    HStack {
                        Text("位置情報の更新間隔")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.safeText)
                        Spacer()
                        Menu {
                            ForEach(intervalOptions, id: \.seconds) { option in
                                Button {
                                    checkInManager.locationManager.updateInterval = option.seconds
                                } label: {
                                    if option.seconds == checkInManager.locationManager.updateInterval {
                                        Label(option.label, systemImage: "checkmark")
                                    } else {
                                        Text(option.label)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedIntervalLabel)
                                    .font(.system(.footnote, design: .rounded, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.safeTeal)
                        }
                        .accessibilityLabel("更新間隔")
                        .accessibilityValue(selectedIntervalLabel)
                    }
                } header: {
                    Text("見守り")
                } footer: {
                    Text("リマインダーはタイマーを自動で開始せず、見守り画面を開くだけです。位置情報の更新間隔は、短くするほど「今すぐ知らせる」時の位置が新しくなりますが、バッテリー消費が増えます。")
                        .font(.system(.caption, design: .rounded))
                }
                .listRowBackground(Color.safeCardFill)

                Section("このアプリについて") {
                    NavigationLink {
                        AboutSottoView(onReplayOnboarding: {
                            onboardingCompleted = false
                        })
                    } label: {
                        HStack {
                            Label("そっとについて", systemImage: "info.circle")
                                .font(.system(.callout, design: .rounded))
                                .foregroundColor(.safeText)
                            Spacer()
                            Text(appVersionText)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundColor(.safeTextFaint)
                        }
                    }
                }
                .listRowBackground(Color.safeCardFill)

                Section {
                    Button(role: .destructive) {
                        showingEraseConfirm = true
                    } label: {
                        Text("この端末のデータをすべて消す")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                    }
                    .foregroundColor(.safeCoral)

                    if didErase {
                        Text("削除しました。")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.safeTeal)
                    }
                } header: {
                    Text("データ")
                } footer: {
                    Text("記録と見守りの連絡先を、この端末から消します。今つけている見守りも止まります。この操作は取り消せません。")
                        .font(.system(.caption, design: .rounded))
                }
                .listRowBackground(Color.safeCardFill)
            }
            .scrollContentBackground(.hidden)
            .background(Color.safeInk)
            .navigationTitle("設定")
            .task { refreshPermissionStatus() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { refreshPermissionStatus() }
            }
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

    private func permissionRow(title: String, status: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.system(.callout, design: .rounded))
                .foregroundColor(.safeText)
            Spacer()
            Text(status)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundColor(.safeTextDim)
        }
        .accessibilityElement(children: .combine)
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "許可済み"
        case .denied: return "許可されていません"
        case .notDetermined: return "未確認"
        @unknown default: return "確認できません"
        }
    }

    private var selectedIntervalLabel: String {
        intervalOptions.first {
            $0.seconds == checkInManager.locationManager.updateInterval
        }?.label ?? "設定済み"
    }

    private var locationStatusText: String {
        switch checkInManager.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "許可済み"
        case .denied, .restricted: return "許可されていません"
        case .notDetermined: return "未確認"
        @unknown default: return "確認できません"
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "バージョン \(version)"
    }

    private func refreshPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
}

/// Numbered step row shared by every step-by-step guide screen in Settings
/// (PDF export guide, shortcut/automation guide) so the two lists can't drift
/// in styling the way two independently-maintained copies of the same view
/// eventually do.
private struct GuideStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundColor(.safeOnAccent)
                .frame(width: 26, height: 26)
                .background(Color.safeTeal)
                .clipShape(Circle())
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.safeText)
        }
        .padding(.vertical, 3)
    }
}

struct PDFExportGuideView: View {
    var body: some View {
        List {
            Section {
                GuideStepRow(number: 1, text: "「記録」タブを開き、Face IDまたはパスコードでロックを解除します。")
                GuideStepRow(number: 2, text: "記録が1件以上あると、画面右上に共有ボタンが表示されます。")
                GuideStepRow(number: 3, text: "共有ボタンを押し、保存先や共有先を選びます。")
            } header: {
                Text("書き出し方法")
            }

            Section {
                Label("共有時に、添付写真を含めるか文章だけにするか選べます。", systemImage: "photo")
                Label("書き出したPDFは暗号化されません。共有先や保存場所を確認し、不要になったら削除してください。", systemImage: "lock.open.trianglebadge.exclamationmark")
            } header: {
                Text("大切な注意")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.safeInk)
        .navigationTitle("PDF書き出し")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutSottoView: View {
    let onReplayOnboarding: () -> Void

    private let privacyPolicyURL = URL(string: "https://matthew0925.github.io/sotto/privacy/")!
    private let supportURL = URL(string: "https://matthew0925.github.io/sotto/support/")!

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "バージョン \(version)（\(build)）"
    }

    var body: some View {
        List {
            Section {
                Text("そっとは、見守り、相談窓口への連絡、出来事の記録を、自分のペースで使うためのアプリです。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.safeText)

                Button {
                    onReplayOnboarding()
                } label: {
                    Label("使い方をもう一度見る", systemImage: "rectangle.on.rectangle")
                        .font(.system(.callout, design: .rounded))
                }
            }

            Section {
                Link(destination: privacyPolicyURL) {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                        .font(.system(.callout, design: .rounded))
                }

                Link(destination: supportURL) {
                    Label("サポート・お問い合わせ", systemImage: "envelope")
                        .font(.system(.callout, design: .rounded))
                }

                NavigationLink {
                    ShortcutGuideView()
                } label: {
                    Label("ショートカットとアクションボタン", systemImage: "button.programmable")
                        .font(.system(.callout, design: .rounded))
                }
            }

            Section {
                Text("アカウント登録や専用サーバーへの送信は行いません。記録本文と添付写真は暗号化し、見守りの連絡先とともにこの端末内へ保存します。位置情報は見守り中の連絡文を作るために使い、アプリのサーバーへ保存・送信しません。")
                Text("設定値もこの端末内に保存されます。「この端末のデータをすべて消す」を実行すると、記録と見守りの連絡先を削除できます。")
                Text("記録をPDFへ書き出す際は、添付写真を含めるか文章だけにするか選べます。写真を含む場合も含めない場合も、書き出したPDFは暗号化されません。")
                Text("PDFとして書き出した記録や、メッセージ・メールなどで共有した内容はアプリの保護対象外です。共有先と保存場所を必ず確認してください。")
                    .foregroundColor(.safeCoral)
                Text("自動SMSショートカットを設定した場合、見守りの終了時刻・連絡先・メッセージ本文はApple純正のショートカットへ渡され、そっとの保護対象外になります。")
                    .foregroundColor(.safeCoral)
            } header: {
                Text("データの保存について")
            }

            Section {
                Text(versionText)
                    .foregroundColor(.safeTextDim)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.safeInk)
        .navigationTitle("そっとについて")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.safeTeal)
    }
}

struct ShortcutGuideView: View {
    var body: some View {
        List {
            Section {
                Label("そっとを開く", systemImage: "leaf.fill")
                Label("見守りを開く", systemImage: "clock.fill")
                Label("110番への電話画面", systemImage: "phone.fill")
            } header: {
                Text("用意されているショートカット")
            } footer: {
                Text("画面を開くだけで、発信、SMS送信、\n見守り開始は自動で行いません。")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("「そっと」のショートカットを開けます。")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.safeTextDim)
                    ShortcutsLink()
                        .shortcutsLinkStyle(.light)
                }
                .padding(.vertical, 6)
            } header: {
                Text("ショートカットアプリ")
            } footer: {
                Text("「そっと」のショートカットを確認したり、\nホーム画面などへ追加したりできます。")
            }

            Section {
                GuideStepRow(number: 1, text: "iPhoneの「設定」で「アクションボタン」を開きます。")
                GuideStepRow(number: 2, text: "「ショートカット」を選びます。")
                GuideStepRow(number: 3, text: "「そっと」を検索し、使いたい操作を選びます。")
            } header: {
                Text("アクションボタンに設定")
            }

            Section {
                Label("見守り情報を取得", systemImage: "message.badge.waveform.fill")
                Text("見守りの期限が過ぎているか、送信先・メッセージ本文を1回だけ取得します。取得しただけでは何も送信されません。")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.safeTextDim)
                Text("期限を過ぎた見守りに対してこの取得を1回行うと、その回の見守りではオートメーションへの送信先の受け渡しが完了した扱いになり、以降は同じ見守りに対して自動送信されません。")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundColor(.safeCoral)
            } header: {
                Text("見守りの自動SMSショートカット")
            } footer: {
                Text("動作確認は、見守りの期限が来る前（まだ超過していないとき）に「見守り情報を取得」を単体で実行してください。期限が過ぎてから試すと、本番のオートメーションが送信できなくなります。")
            }

            Section {
                GuideStepRow(number: 1, text: "ショートカットアプリ →「オートメーション」タブ → 右上「＋」→「オートメーションを作成」")
                GuideStepRow(number: 2, text: "一覧から「アプリ」を選び、「そっと」→「開いたとき」を選んで「完了」（後から時刻トリガー等に変更できます）")
                GuideStepRow(number: 3, text: "「次へ」で「新規空白オートメーション」を選ぶ（候補テンプレートは選ばない）")
                GuideStepRow(number: 4, text: "「アクションを追加」→「そっと」を検索 →「見守り情報を取得」を追加")
                GuideStepRow(number: 5, text: "「アクションを追加」→「もし」を検索して追加し、条件欄で直前の結果から「期限超過」を選び「真」に設定")
                GuideStepRow(number: 6, text: "「もし」の中に「メッセージを送信」を追加し、宛先・本文の各欄をタップして「送信先」「メッセージ」の変数を選ぶ（直接入力しない）")
                GuideStepRow(number: 7, text: "「次へ」→「実行前に尋ねる」をオフにして「完了」")
            } header: {
                Text("自動SMS化オートメーションの組み立て方")
            } footer: {
                Text("手順3で空白オートメーションを選ばなかった場合と、手順6で固定テキストを入力してしまった場合が、うまく動かない一番多い原因です。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.safeInk)
        .navigationTitle("ショートカット")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.safeTeal)
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
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    if !iconManager.supportsAlternateIcons {
                        Text("この端末ではアイコンの切り替えに対応していません。")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundColor(.safeTextFaint)
                    } else {
                        // Chunked rather than a hardcoded prefix(3)/suffix(2) split so
                        // adding or removing an AppIconOption case can't silently drop
                        // an icon out of every row instead of just reflowing.
                        VStack(spacing: 22) {
                            ForEach(Array(iconRows.enumerated()), id: \.offset) { _, row in
                                iconRow(row)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 20)
                        .background(Color.safeCardFill.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        if let error = iconManager.lastErrorMessage {
                            Text(error)
                                .font(.system(.caption, design: .rounded))
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

    private var iconRows: [[AppIconOption]] {
        stride(from: 0, to: AppIconOption.allCases.count, by: 3).map { start in
            Array(AppIconOption.allCases[start..<min(start + 3, AppIconOption.allCases.count)])
        }
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
                    .font(.system(.caption, design: .rounded))
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
