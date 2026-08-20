import SwiftUI

/// Shown once, on first launch (gated by `sotto.onboarding.completed` in
/// ContentView). Walks through what each tab does before dropping the user
/// into the app — the lack of this was a big part of the app feeling thin.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(icon: "hand.point.up.left.fill",
             title: "そっとへようこそ",
             body: "そっとは、危ないと感じたとき、\n迷わず助けを呼べる場所。\nあなたのための、静かな安全アプリです。"),
        Page(icon: "circle.fill",
             title: "必要なときは110番へ",
             body: "ホーム画面のボタンを1.5秒長押しすると、\n110番の発信確認が開きます。\n触れただけでは発信されません。"),
        Page(icon: "clock.fill",
             title: "見守りチェックイン",
             body: "出かける前にセットしておくと、\n時間になったときに通知します。通知を開くと、\n選んだ人へのSMS作成画面へ進みます。\n\n（上級者向け）ショートカットで自動送信も設定できますが、\n組み立てにはApple純正アプリでの操作が必要です。"),
        Page(icon: "note.text",
             title: "記録はあなたのために",
             body: "気になったことを、そっと書き留めておけます。\n暗号化してこの端末の中だけに残ります。\nFace ID・Touch ID・パスコードで保護します。"),
        Page(icon: "lock.shield.fill",
             title: "アカウント登録は不要です",
             body: "氏名もメールアドレスも聞きません。\nデータは暗号化してこの端末の中だけに残ります。")
    ]

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "次へ" : "はじめる")
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.safeTeal)
                        .foregroundColor(.safeOnAccent)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                if page < pages.count - 1 {
                    Button("スキップ") { onFinish() }
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.safeTextFaint)
                        .padding(.bottom, 24)
                } else {
                    Color.clear.frame(height: 1).padding(.bottom, 24)
                }
            }
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 46))
                .foregroundColor(.safeTeal)
                .frame(width: 96, height: 96)
                .background(Color.safeCardFill)
                .clipShape(Circle())
            Text(page.title)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(.safeText)
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(.system(size: 14.5, design: .rounded))
                .foregroundColor(.safeTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            Spacer()
        }
    }
}
